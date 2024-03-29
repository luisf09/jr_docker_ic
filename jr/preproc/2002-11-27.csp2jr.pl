#!/usr/bin/perl -w
#

use strict;

# global variables -- initialized in code.
# scan:
my $tok;
my $realtok;
my $line;
my $wholeline;

# error:
my $exitstatus;
my $errorcnt;
my $MAXERRCNT;
my $Ifile;

my $JR_HOME; # from environment variable

# banner to protect against clobbering good .jr file
my $cmdname = basename($0,"");
my $fsuffix = "csp";
my $BANNER="/* This JR file was generated by $cmdname */";

# which termination discipline.
my $termdisc = "-ti";
my %td; # table for pretty error messages

# semantics
my $seenspecs;
my $nest; # nesting level of _if and _do
my $process_name; # name of current _process

$td{"-ti"} = "implicit";
$td{"-te"} = "explicit";

main();

sub main {

  $exitstatus = 0; # in case no command line args, so terminate works.

  # only allow termination discipline as first argument.
  my @newargv;
  my $got = 0;
  foreach my $a (@ARGV) {
    if ($a =~ /^-ti$/ || $a =~ /^-te$/ ) {
      if ($got != 0) {
	$! = 1;
        die "multiple termination disciplines as command line options\n";
      }
      $termdisc = $a;
      $got = 1;
    }
    elsif ($a =~ /^-/) {
      $! = 1;
      die "unknown command line option\n";
    }
    else {
      push(@newargv, $a);
    }
  }

  foreach my $a (@newargv) {
    # make sure it's a $fsuffix file
    if ("$a" !~ /\.$fsuffix$/) {
      $! = 1;
      die "usage: $cmdname file.$fsuffix\n";
    }
    my $basen = basename($a,".$fsuffix");
##  print "$basen\n";
    my $newn = $basen . ".jr";
    # if .jr output file exists, check that it was generated by this tool
    # so that we do not mistakenly blow away a good file.
    if ( -r "$newn" ) {
      open(F, "$newn");
      my $line1 = <F>;
      chop($line1);
      if ("$line1" ne "$BANNER") {
        $! = 1;
        die "$newn exists and was not created by $cmdname " .
            "- will not overwrite\n";
      }
      close(F);
    }
    if (!open(I, "$a")) { # input file
      $! = 1;
      die "can't open $a\n";
    }
    $Ifile = "$a";
    if (!open(O, "> $newn")) { # output file
      $! = 1;
      die "can't open $newn\n";
    }
    do1file();
    close(I);
    close(O);
  }
  if ( checkenv() ) {
    my $PREPROC = "$JR_HOME/preproc/";
    use File::Copy;
    copy("$PREPROC/csp_coord.jr",".");
    copy("$PREPROC/csp_pdecl.jr",".");
    copy("$PREPROC/csp_pidx.jr",".");
    copy("$PREPROC/csp_rr.jr",".");
  }
  terminate();
}

sub do1file {

  # (re-)initialize globals
  $tok = ""; # anything not "EOF"
  $realtok = "(**EOF**)";
  $line = "";
  $wholeline = "";

  $exitstatus = 0;
  $errorcnt = 0;
  $MAXERRCNT = 20;

  $seenspecs = 0;
  $nest = 0;
  $process_name = "";

  print O "$BANNER\n";
  print O "/* for the $td{$termdisc} termination disciple */\n\n";
  parse();
  print O "\n";

}

sub parse {
  scan();
  while ($tok ne "EOF") {
    if ($tok eq "ID") {
      if ($realtok eq "_program") {
        cprogram();
      }
      elsif ($realtok =~ /^_/) {
        error("_ID found outside of _program");
      }
      else {
        outln($realtok);
      }
    }
    else {
      out($realtok);
    }
    scan();
  }
  if ($tok ne "EOF") {
    error("junk after logical end of input");
  }
}


sub cprogram {
  mustbe("ID"); # skip over _program
  my $progname = mustbe("ID");
  my $mainname = ""; # user's main
  if ($tok eq "ID" && $realtok eq "_main") {
    scan(); # skip over _main
    $mainname = mustbe("ID");
  }
  outln("import java.util.Vector;");
  outln("import edu.ucdavis.jr.JR;");
  outln("public class ".$progname." {");
  my $t = ($termdisc eq "-ti"?"true":"false");
  outln("  private static final boolean csp_implicit = $t;");
  outln("  private static csp_coord csp_ch;");
  outln("  private static cap void (boolean,int,int,int,int) [] csp_reply;");
  outln("  private static csp_pidx [] csp_pidxs;");
  # generate main method
  # among other things, it allocates objects
  # for things that depends on number of processes.
  outln("  public static void main(String [] args) {");
  outln("    try {");
  outln("    csp_reply = new cap void (boolean,int,int,int,int) [csp_np];");
  outln("    for (int k = 0; k < csp_np; k++) {");
  outln("      csp_reply[k] = new op void (boolean,int,int,int,int);");
  outln("    }");
  outln("    csp_pidxs = new csp_pidx [csp_np];");
  outln("    int csp_k = 0;");
  outln("    for (int csp_p = 0; csp_p < csp_pdecls.size(); csp_p++) {");
  outln("      csp_pdecl csp_d = (csp_pdecl) csp_pdecls.elementAt(csp_p);");
  outln("      for (int csp_i1 = 0; csp_i1 < csp_d.s1; csp_i1++) {");
  outln("        for (int csp_i2 = 0; csp_i2 < csp_d.s2; csp_i2++) {");
  outln("          csp_pidxs[csp_k++] = new csp_pidx(csp_p,csp_i1,csp_i2);");
  outln("        }");
  outln("      }");
  outln("    }");
  outln("    csp_ch = new csp_coord(csp_np, csp_implicit, csp_reply,");
  outln("                           csp_pidxs, csp_pdecls);");

  # call user's main, if one was specified.
  if ($mainname ne "") {
    outln("    $mainname(args);");
  }
  outln("    for (int k = 0; k < csp_pdecls.size(); k++) {");
  outln("    csp_pdecl d = (csp_pdecl) csp_pdecls.elementAt(k);");
  outln("    for (int q1 = 0; q1 < d.s1; q1++) {");
  outln("      for (int q2 = 0; q2 < d.s2; q2++) {");
  outln("        send d.cp(q1,q2);");
  outln("      }");
  outln("    }");
  outln("  }");
  outln("  } catch (Exception oops) {oops.printStackTrace();}");
  outln("}");
  
  block();
  out("}");
}

# note: this checks for "{" and "}"
# but invoker must out() those as desired.
sub block {
  mustbe("{");
  while ($tok ne "EOF" && $tok ne "}") {
##print "tok is $tok\n";
##print "realtok is $realtok\n";
    if ($tok eq "{") {
      out("{");
      block();
      out("}");
    }
    elsif ($tok eq "ID") {
      if ($realtok eq "_specs") {
        $seenspecs++;
        if ($seenspecs > 1) {
          error("multiple _specs found within _program");
        }
        cspecs();
      }
      elsif ($realtok eq "_process") {
        if ($seenspecs == 0) {
          error("_process must appear after _specs");
        }
        cprocess();
      }
      elsif ($realtok eq "_dump_pidx") {
        dump_pidx();
      }
      elsif ($realtok eq "_csp_status") {
        # this should be helpful to the user in debugging
        cstatus();
      }
      elsif ($realtok eq "_i") {
        cio("i", 0);
      }
      elsif ($realtok eq "_o") {
        cio("o", 0);
      }
      elsif ($realtok eq "_if") {
        cif();
      }
      elsif ($realtok eq "_do") {
        cdo();
      }
      else { # i.e., non-interesting id.
        outln($realtok);
        scan();
      }
    }
    else { # i.e., not id
      out($realtok);
      scan();
    }
  }
  mustbe("}");
##  print "tok is $tok\n";
##  print "realtok is $realtok\n";
}

sub cspecs {
  mustbeid("_specs");
  outln("  private static int csp_np = 0;");
  outln("  private static int csp_nt = 0;");
  outln("  private static int csp_npdecls = 0;");
  outln("  private static Vector csp_pdecls = new Vector();");

  mustbe("{");
  while ($tok ne "EOF" and $tok ne "}") {
    process_spec();
  }
  mustbe("}");
}

sub process_spec {
  my $pname;
  my $cnt;
  my $e1;
  my $e2;
  while ($tok ne "EOF" and $tok ne "}") {
    ($cnt, $pname, $e1, $e2) = pnameandsubs();
    if ($cnt == 0) {
      gen_process_spec($pname);
    }
    elsif ($cnt == 1) {
      gen_process_spec1($pname,$e1);
    }
    elsif ($cnt == 2) {
      gen_process_spec2($pname,$e1,$e2);
    }
    else {
      error("oops -- I can't count $cnt in process_spec($pname)");
    }
    port($pname);
  }
}

sub port {
##print "port\n";
  my $pname = shift(@_);
  mustbe("{");
  while ($tok ne "EOF" and $tok ne "}") {
    my $oname = mustbe("ID");
    my $ospec = grabmatch("(",")",1,0);
##print "pname=" . $pname . "\n";
##print "oname=" . $oname . "\n";
##print "ospec=" . $ospec . "\n";
    gen_port($pname,$oname,$ospec);
    mustbe(";");
  }
  mustbe("}");
}

sub cprocess {
  mustbeid("_process");
  my $pname = mustbe("ID");
  $process_name = $pname;
  my $cnt = 0;
  my @subs;
  my $loop = $tok eq "(";
  while ($loop) {
    scan();
    $subs[$cnt] = mustbe("ID");
    $cnt++;
    if ($cnt > 2) {
      error("only two-dimensions allowed");
      terminate();
      # if keep going, get erros on internal checks, which would confuse user.
    }
    if ($tok eq ",") {
      $loop = 1;
    }
    elsif ($tok eq ")") {
      scan();
      $loop = 0;
    }
    else {
      error("can't parse _process list of ids");
    }
  }
  if ($cnt == 0) {
    gen_process_body($pname);
  }
  elsif ($cnt == 1) {
    gen_process_body1($pname,$subs[0]);
  }
  elsif ($cnt == 2) {
    gen_process_body2($pname,$subs[0],$subs[1]);
  }
  else {
    error("oops -- I can't count $cnt in cprocess($pname)");
  }
  block();
  gen_process_end();
}

sub cif {
  cifdo("_if","_fi");
}
sub cdo {
  cifdo("_do","_od");
}
sub cifdo {
  my $open = shift(@_);
  my $close = shift(@_);
  $nest++;
  mustbeid($open);
  if ($open eq "_do") {
    gen_do();
  }
  else {
    gen_if();
  }
  my $seenone = 0;
  while( $tok ne "EOF" && $realtok ne $close) {
    cifdoarm();
    $seenone = 1;
  }
  if ($seenone == 0) {
    print_error("warning: _if or _do has no arms");
  }
  mustbeid($close);
  if ($open eq "_do") {
    gen_od();
  }
  else {
    gen_fi();
  }
  $nest--;
}

sub cifdoarm {
  if ($tok ne "ID") {
    error("bad start of arm in _if or _do");
  }
  if ($realtok eq "_i") {
    cio("i",1);
  }
  elsif ($realtok eq "_o") {
    cio("o",1);
  }
  elsif ($realtok eq "_g") {
    cguard();
  }
  else {
    error("bad start of arm in _if or _do");
  }
}

sub cguard {
  mustbeid("_g"); # skip _g
  my %q;
  my $qn = 3; # number of "elements" per entry in %q
  %q = quantifiers();
  if ( (keys(%q) % $qn) != 0 ) {
    error("oops -- quantifier table foul up $qn \n");
  }
  my $qcnt = keys(%q) / $qn;
##print "length of q is " . keys(%q) . " $qcnt \n";
  my $expr = grabmatch("(",")",1,1);
  if ($qcnt == 0) {
    gen_guard($expr);
  }
  elsif ($qcnt == 1) {
    gen_guard1($q{"v",0}, $q{"l",0}, $q{"u",0}, $expr);
  }
  elsif ($qcnt == 2) {
    gen_guard2($q{"v",0}, $q{"l",0}, $q{"u",0},
               $q{"v",1}, $q{"l",1}, $q{"u",1},
               $expr);
  }
  else {
    error("oops -- I can't count $qcnt in guard");
  }
  block();
}


sub cio {
  my $dir = shift(@_);
  my $guard = shift(@_); # parsing a guard? allow expr.
  my $expr = "true"; # default expression
  mustbe("ID"); # skip _i or _o
  my %q;
  my $qn = 3; # number of "elements" per entry in %q
  %q = quantifiers();
  if ( (keys(%q) % $qn) != 0 ) {
    error("oops -- quantifier table foul up $qn \n");
  }
  my $qcnt = keys(%q) / $qn;
##print "length of q is " . keys(%q) . " $qcnt \n";
  if ($guard == 1) {
    if ($tok eq "(") {
      $expr = grabmatch("(",")",1,1);
    }
  }
  my $pname;
  my $cnt;
  my $e1;
  my $e2;
  ($cnt, $pname, $e1, $e2) = pnameandsubs();
  if (($dir eq "i" && $tok eq "?") || ($dir eq "o" && $tok eq "!")) {
    # optional ! and ?
    scan();
  }
  elsif ($tok eq "?" || $tok eq "!") {
    print_error("warning: contradictory _$dir and $tok; using _$dir");
    scan();
  }
  my $pall = $pname;
  if ($cnt >= 1) {
    $pall = $pall . "[$e1]";
  }
  if ($cnt >= 2) {
    $pall = $pall . "[$e2]";
  }
  my $ouse = mustbe("ID");
  # last arg to grabmatch:
  # arguments for "o" can be expressions, but for "i" better be variables.
  my $args = grabmatch("(",")",1,$dir eq "o");
  # for input, process name to use is current _process.
  # for output, process name to use is named _process.
  if ($process_name eq "") {
    error("input or output statement or guard outside of _process");
    terminate();
  }
  if ($guard == 0) {
    mustbe(";");
    if ($qcnt == 0) {
      gen_stmt_io($dir, $pname, $pall, $ouse, $args);
    }
    elsif ($qcnt == 1) {
      gen_stmt_io1($dir, $q{"v",0}, $q{"l",0}, $q{"u",0},
                   $pname, $pall, $ouse, $args);
    }
    elsif ($qcnt == 2) {
      gen_stmt_io2($dir, $q{"v",0}, $q{"l",0}, $q{"u",0},
                         $q{"v",1}, $q{"l",1}, $q{"u",1},
                   $pname, $pall, $ouse, $args);
    }
    else {
      error("oops -- I can't count $cnt in $dir statement");
    }
  }
  else {
    if ($qcnt == 0) {
      gen_guard_io($dir, $expr, $pname, $pall, $ouse, $args);
    }
    elsif ($qcnt == 1) {
      gen_guard_io1($dir, $q{"v",0}, $q{"l",0}, $q{"u",0},
                   $expr, $pname, $pall, $ouse, $args);
    }
    elsif ($qcnt == 2) {
      gen_guard_io2($dir, $q{"v",0}, $q{"l",0}, $q{"u",0},
                         $q{"v",1}, $q{"l",1}, $q{"u",1},
                   $expr, $pname, $pall, $ouse, $args);
    }
    else {
      error("oops -- I can't count $qcnt in $dir guard");
    }
    block();
  }
}


# allow at most 2-d processes and operations.
# for simplicity, turn all processes and operations into 2-d.

# np is number of processes
# nt is number of types
# these counters are used for assigning unique identifiers
# to each process and to each type.
#
# csp_pdecls contains info on all process declarations;
# each process is represented by a csp_pdecl object.

# declare the sizes on this process as constants
sub gen_declare_pbounds {
  my $name = shift(@_);
  my $s_1 =  shift(@_);
  my $s_2 =  shift(@_);
  outln("private static final int csp_$name\_s1 = $s_1;");
  outln("private static final int csp_$name\_s2 = $s_2;");
}

sub gen_save_pdecl {
  my $name = shift(@_);
  my $dims =  shift(@_);
  my $s_1 =  shift(@_);
  my $s_2 =  shift(@_);
  outln("  csp_pdecls.addElement( new csp_pdecl(\"$name\",$dims, ");
  outln("                         csp_$name,$s_1,$s_2));");
}

# only for debugging csp2jr
sub dump_pidx {
  mustbeid("_dump_pidx");
  outln("{");
  outln("  for (int csp_k = 0; csp_k < csp_np; csp_k++) {");
  outln("    System.out.println(csp_k+\" \"+csp_pidxs[csp_k].i1+\" \"+");
  outln("                                 csp_pidxs[csp_k].i2);");
  outln("  }");
  outln("}");
}

sub cstatus {
  mustbeid("_csp_status");
  my $brief = grabmatch("(",")",1,1); # brief or verbose
  outln("call csp_ch.csp_status(csp_pid,$brief)");
}

# set up to work for only 2d
# could easily generalize (use recursion),
# but there are other restrictions on 2d.
sub gen_process_spec2 {
  my $name = shift(@_);
  my $s_1 =  shift(@_);
  my $s_2 =  shift(@_);
  outln("private static op void csp_$name (int,int);");
  gen_declare_pbounds($name, $s_1, $s_2);
  outln("private static int [][] $name;");
  outln("static {");
  outln("  $name = new int [$s_1][$s_2];");
  outln("  for (int csp_k = 0; csp_k < $s_1; csp_k++) {");
  outln("    for (int csp_h = 0; csp_h < $s_2; csp_h++) {");
  outln("      $name\[csp_k][csp_h] = csp_np++;");
  outln("    }");
  outln("  }");
  gen_save_pdecl($name, 2, $s_1, $s_2);
  outln("}");
}

sub gen_process_spec1 {
  my $name = shift(@_);
  my $s_1 =  shift(@_);
  outln("private static op void csp_$name (int,int);");
  gen_declare_pbounds($name, $s_1, 1);
  outln("private static int [] $name;");
  outln("static {");
  outln("  $name = new int [$s_1];");
  outln("  for (int csp_k = 0; csp_k < $s_1; csp_k++) {");
  outln("    $name\[csp_k] = csp_np++;");
  outln("  }");
  gen_save_pdecl($name, 1, $s_1, 1);
  outln("}");
}

sub gen_process_spec {
  my $name = shift(@_);
  outln("private static op void csp_$name (int,int);");
  gen_declare_pbounds($name, 1, 1);
  outln("private static int $name;");
  outln("static {");
  outln("  $name = csp_np++;");
  gen_save_pdecl($name, 0, 1, 1);
  outln("}");
}


# note: op names are made globally unique
# by pasting process name onto them.
# (so when do invocation, paste on process name (but not subscripts) too.)
sub portname {
  my $pname = shift(@_);
  my $oname =  shift(@_);
  return "csp_$pname\_$oname";
}

sub gen_port {
  my $pname = shift(@_);
  my $oname =  shift(@_);
  my $ospec =  shift(@_);
  my $o = portname($pname,$oname);
  outln("private static cap void ($ospec) [][] $o = ");
  outln("           new cap void ($ospec)");
  outln("[ csp_$pname\_s1 ]");
  outln("[ csp_$pname\_s2 ];");
  outln("private static int csp_type_$o;");
  outln("static {");
  outln("  try {");
  outln("  csp_type_$o = csp_nt++;");
  outln("  for (int csp_q1 = 0; csp_q1 < csp_$pname\_s1; csp_q1++) {");
  outln("    for (int csp_q2 = 0; csp_q2 < csp_$pname\_s2; csp_q2++) {");
  outln("      $o\[csp_q1][csp_q2] = new op void ($ospec);");
  outln("    }");
  outln("  }");
  outln("  } catch (Exception oops) {oops.printStackTrace();}");
  outln("  }");
}

# assign each process its own process id.
sub gen_process_body2 {
  my $name = shift(@_);
  my $v1 =  shift(@_);
  my $v2 =  shift(@_);
  outln("private static void csp_$name (int $v1, int $v2) {");
  outln("try {");
  outln("  int csp_pid = $name\[$v1][$v2];");
}
sub gen_process_body1 {
  my $name = shift(@_);
  my $v1 =  shift(@_);
  # note: csp_x2 not used.
  outln("private static void csp_$name (int $v1, int csp_x2) {");
  outln("try {");
  outln("  int csp_pid = $name\[$v1];");
}
sub gen_process_body {
  my $name = shift(@_);
  # note: csp_x1 and csp_x2 not used.
  outln("private static void csp_$name (int csp_x1, int csp_x2) {");
  outln("try {");
  outln("  int csp_pid = $name;");
}

sub gen_process_end {
  outln("send csp_ch.csp_die(csp_pid);");
  outln("} catch (Exception oops) {oops.printStackTrace();}");
  outln("}");
}

# input and output stmts.
# pname is process name, e.g., B, B[3], B[i,j], of sender or receiver.
# ouse is operation of receiver; args are its parameters.
# csp_arm, csp_q1, csp_q2 aren't used here.
#
# csp_err semaphore is used to block the process after it invokes
# error and shutdown operation in coordinator.
# never should get past P on csp_err.

sub gen_stmt_io2 {
  my $dir =  shift(@_); # "i" for input "o" for output
  my $v1 =  shift(@_);
  my $l1 =  shift(@_);
  my $u1 =  shift(@_);
  my $v2 =  shift(@_);
  my $l2 =  shift(@_);
  my $u2 =  shift(@_);
  my $pname =  shift(@_);
  my $pall =  shift(@_);
  my $ouse =  shift(@_);
  my $args =  shift(@_);
  my $w = portname( ($dir eq "i"? $process_name : $pname) ,$ouse);
  my $t; # just for computing diff for input or output
  outln("{");
  outln("boolean csp_ok;");
  outln("int csp_with, csp_arm, csp_q1, csp_q2;");
  outln("Vector csp_vrr = new Vector();");
  outln("for (int $v1 = $l1; $v1 <= $u1; $v1++ ) {");
  outln("  for (int $v2 = $l2; $v2 <= $u2; $v2++ ) {");
  $t = ($dir eq "i"?"true":"false");
  outln("    csp_vrr.addElement( new csp_rr( $pall, $t, csp_type_$w,");
  outln("	                 0, 0, 0 ) );");
  outln("  }");
  outln("}");
  outln("send csp_ch.csp_match(csp_pid, csp_vrr);");
  outln("receive csp_reply[csp_pid](csp_ok,csp_with,csp_arm,csp_q1,csp_q2);");
  outln("if (!csp_ok) {");
  outln("  send csp_ch.csp_cantmatch(csp_pid,");
  $t = ($dir eq "i"?"input":"output");
  outln("    \"cannot match $t stmt (user error) \"+");
  my $printargs = $args;
  $printargs =~ s/ *$//; # chop off any trailing blanks
  $printargs = ($dir eq "i"?"($printargs)":$printargs);
  $t = ($dir eq "i"?"?":"!");
  outln("    \"$pall$t$ouse$printargs\");");
#### original:  outln("    \"$pall $ouse ($printargs)\");");
  outln("  P(csp_ch.csp_err);");
  outln("}");
  $t = ($dir eq "i"?"csp_pid":"csp_with");
  outln("csp_pidx csp_t = csp_pidxs[$t];");
  $t = ($dir eq "i"?"receive":"send");
  my $theargs = ($dir eq "i"?"(".$args.")":$args);
  outln("$t $w [csp_t.i1][csp_t.i2] $theargs;");
  outln("}");
}

sub gen_stmt_io1 {
  my $dir =  shift(@_);
  my $v1 =  shift(@_);
  my $l1 =  shift(@_);
  my $u1 =  shift(@_);
  my $pname =  shift(@_);
  my $pall =  shift(@_);
  my $ouse =  shift(@_);
  my $args =  shift(@_);
  gen_stmt_io2($dir, $v1, $l1, $u1, "csp_v2", 0, 0,
               $pname, $pall, $ouse, $args);
}

sub gen_stmt_io {
  my $dir =  shift(@_);
  my $pname =  shift(@_);
  my $pall =  shift(@_);
  my $ouse =  shift(@_);
  my $args =  shift(@_);
  gen_stmt_io2($dir, "csp_v1", 0, 0, "csp_v2", 0, 0,
               $pname, $pall, $ouse, $args);
}

# csp if stmt -- i.e., containing i/o commands in guards.
# generate prologue and epilogue for rest of stmt.
# _if generates "begin; if true -> if true"
# since guards require "->" after guard
# and _fi always generate "fi; fi; end".
# that's needed to include the stmt list code (i.e., "user" code) within if.
# initialize csp_q1 and csp_q2 just to keep Java happy.
#
# csp_arm_cnt is used to assign an arm number to each arm.
# csp_arm is number of arm selected to execute.
sub gen_if {
  outln("{");
  outln("boolean csp_$nest\_ok;");
  outln("int csp_$nest\_with = -9999;");
  outln("int csp_$nest\_q1 = -9999, csp_$nest\_q2 = -9999;");
  outln("int csp_$nest\_arm = 0;");
  outln("boolean csp_$nest\_gfound = false;");
  outln("boolean csp_$nest\_iofound = false;");
  outln("Vector csp_$nest\_vrr = new Vector();");
  outln("for (int csp_$nest\_pass = 1; csp_$nest\_pass <= 2;");
  outln("         csp_$nest\_pass++) {");
  outln("  int csp_$nest\_arm_cnt = 0;");
  outln("  {");
  outln("    if (true) {");
  outln("      if (true) {");
}
sub gen_fi {
  gen_fi_od();
  outln("}");
}

sub gen_fi_od {
  outln("      }");
  outln("    }");
  outln("  }");
  outln("  if (csp_$nest\_pass == 1 && ! csp_$nest\_gfound &&");
  outln("                               csp_$nest\_iofound) {");
  outln("    send csp_ch.csp_match(csp_pid,csp_$nest\_vrr);");
  outln("    receive csp_reply[csp_pid](csp_$nest\_ok,csp_$nest\_with,");
  outln("                      csp_$nest\_arm,csp_$nest\_q1,csp_$nest\_q2);");
  outln("    if (!csp_$nest\_ok) { break; }");
  outln("  }");
  outln("}");
}

sub gen_do {
  outln("while (true) {");
  gen_if();
}

sub gen_od {
  gen_fi_od();
  outln("  if (! csp_$nest\_gfound && csp_$nest\_arm == 0 ) { break; }");
  outln("  }");
  outln("}");
}


# input and output guards.
# (the generated code uses the "two pass technique" since that's
# considerably easier to generate.)
sub gen_guard_io2 {
  my $dir =  shift(@_); # "i" for input "o" for output
  my $v1 =  shift(@_);
  my $l1 =  shift(@_);
  my $u1 =  shift(@_);
  my $v2 =  shift(@_);
  my $l2 =  shift(@_);
  my $u2 =  shift(@_);
  my $expr =  shift(@_);
  my $pname =  shift(@_);
  my $pall =  shift(@_);
  my $ouse =  shift(@_);
  my $args =  shift(@_);
  my $w = portname( ($dir eq "i"? $process_name : $pname) ,$ouse);
  my $t; # just for computing diff for input or output
  outln("    }");
  outln("  }");
  outln("}");
  outln("{");
  outln("  int csp_$nest\_my_arm = ++csp_$nest\_arm_cnt;");
  outln("  if (csp_$nest\_pass == 1 && ! csp_$nest\_gfound) {");
  outln("    for (int $v1 = $l1; $v1 <= $u1; $v1++) {");
  outln("      for (int $v2 = $l2; $v2 <= $u2; $v2++) {");
  outln("        if ($expr) {");
  outln("          csp_$nest\_iofound = true;");
  $t = ($dir eq "i"?"true":"false");
  outln("          csp_$nest\_vrr.addElement( new");
  outln("           csp_rr( $pall, $t, csp_type_$w,");
  outln("                   csp_$nest\_my_arm, $v1, $v2 ));");
  outln("        }");
  outln("      }");
  outln("    }");
  outln("  }");
  outln("  else if (csp_$nest\_pass == 2 &&");
  outln("           csp_$nest\_arm == csp_$nest\_my_arm) {");
  $t = ($dir eq "i"?"csp_pid":"csp_$nest\_with");
  outln("    csp_pidx csp_$nest\_t = csp_pidxs[$t];");
  $t = ($dir eq "i"?"receive":"send");
  my $theargs = ($dir eq "i"?"(".$args.")":$args);
  outln("    $t $w [csp_$nest\_t.i1][csp_$nest\_t.i2] $theargs;");
  outln("    int $v1 = csp_$nest\_q1; int $v2 = csp_$nest\_q2;");
  outln("    if (true) {");
}

sub gen_guard_io1 {
  my $dir =  shift(@_);
  my $v1 =  shift(@_);
  my $l1 =  shift(@_);
  my $u1 =  shift(@_);
  my $expr =  shift(@_);
  my $pname =  shift(@_);
  my $pall =  shift(@_);
  my $ouse =  shift(@_);
  my $args =  shift(@_);
  gen_guard_io2($dir, $v1, $l1, $u1, "csp_$nest\_v2", 0, 0,
                      $expr, $pname, $pall, $ouse, $args);
}

sub gen_guard_io {
  my $dir =  shift(@_);
  my $expr =  shift(@_);
  my $pname =  shift(@_);
  my $pall =  shift(@_);
  my $ouse =  shift(@_);
  my $args =  shift(@_);
  gen_guard_io2($dir, "csp_$nest\_v1", 0, 0, "csp_$nest\_v2", 0, 0,
                $expr, $pname, $pall, $ouse, $args);
}

# guards with no I/O commands.
# allow quantifiers here too.
# check if expr is true on first pass;
# if so, then execute statement list and get out.
# initialize csp_my_arm just to keep Java happy.
sub gen_guard2 {
  my $v1 =  shift(@_);
  my $l1 =  shift(@_);
  my $u1 =  shift(@_);
  my $v2 =  shift(@_);
  my $l2 =  shift(@_);
  my $u2 =  shift(@_);
  my $expr =  shift(@_);
  outln("    }");
  outln("  }");
  outln("}");
  outln("{");
  outln("  int csp_$nest\_my_arm = ++csp_$nest\_arm_cnt;");
  outln("  if (csp_$nest\_pass == 1 && ! csp_$nest\_gfound) {");
  outln("    for (int $v1 = $l1; $v1 <= $u1; $v1++) {");
  outln("      for (int $v2 = $l2; $v2 <= $u2; $v2++) {");
  outln("        if ($expr) {");
  outln("          csp_$nest\_q1 = $v1; csp_$nest\_q2 = $v2;");
  outln("          csp_$nest\_arm = csp_$nest\_my_arm;");
  outln("          csp_$nest\_gfound = true;");
  outln("          break;");
  outln("        }");
  outln("      }");
  outln("      if (csp_$nest\_gfound) { break; }");
  outln("    }");
  outln("  }");
  outln("  else if (csp_$nest\_pass == 2 && ");
  outln("           csp_$nest\_arm == csp_$nest\_my_arm) {");
  outln("    int $v1 = csp_$nest\_q1; int $v2 = csp_$nest\_q2;");
  outln("    if (true) {");
}

sub gen_guard1 {
  my $v1 =  shift(@_);
  my $l1 =  shift(@_);
  my $u1 =  shift(@_);
  my $expr =  shift(@_);
  gen_guard2($v1, $l1, $u1, "csp_$nest\_v2", 0, 0, $expr);
}

sub gen_guard {
  my $expr =  shift(@_);
  gen_guard2("csp_$nest\_v1", 0, 0, "csp_$nest\_v2", 0, 0, $expr);
}

# process name, possibly followed by [e1][e2]
# returns a list:
#  number of subscripts
#  name
#  e1
#  e2
# (e1 and e2 returned only if they exist.)
# each return value is a string of tokens,
# which are output later as needed.
sub pnameandsubs {
  my $pname = mustbe("ID");
  my $cnt = 0;
  my @subs;
  while ($tok eq "[") {
    $subs[$cnt] = grabmatch("[","]",1,0);
    $cnt++;
    if ($cnt > 2) {
      error("only two-dimensions allowed");
      terminate();
      # if keep going, get erros on internal checks, which would confuse user.
    }
  }
  return ($cnt, $pname, @subs);
}

# quantifiers 
# returns a list:
#  number of quantifiers
#  list of variable names
#  list of lower bounds
#  list of upper bounds
# each return value is a string of tokens,
# which are output later as needed.
#
# originally wanted to return 3 separate lists,
# (qv, ql, and qu) but can't return list of lists in Perl.
# also list of tables gets converted to list...
# (book says something about reference to list, but gives no details.)
# so, return fancier table.
sub quantifiers {
  my $qcnt = 0;
  my %q;
  while ($realtok eq "[") {
    scan();
    $q{"v",$qcnt} = mustbe("ID");
    if ($realtok ne "=") {
      print_error("missing = in quantifier inserted");
    }
    else {
      scan();
    }
    $q{"l",$qcnt} = grabupto("_to");
    $q{"u",$qcnt} = grabmatch("[","]",0,0);
    $qcnt++;
    if ($qcnt > 2) {
      error("at most two quantifiers allowed");
    }
  }
##print "in q: qcnt is $qcnt\n";
##print "in q: length of q is " . keys(%q) . "\n";
  return %q;
}

