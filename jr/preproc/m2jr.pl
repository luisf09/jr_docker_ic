
my $fsuffix = "m";

# which signaling discipline.
my $sigdisc = "-sc";
my %sd; # table for pretty error messages

$sd{"-sc"} = "signal and continue";
$sd{"-sw"} = "signal and wait";
$sd{"-su"} = "signal and urgent wait";
$sd{"-sx"} = "signal and exit";

main();

sub main {

  $exitstatus = 0; # in case no command line args, so terminate works.

  # only allow signaling discipline as first argument.
  my @newargv;
  my $got = 0;
  foreach my $a (@ARGV) {
    if ($a =~ /^-sc$/ || $a =~ /^-sw$/ ||
        $a =~ /^-su$/ || $a =~ /^-sx$/ ) {
      if ($got != 0) {
	$! = 1;
        die "multiple signaling disciplines as command line options\n";
      }
      $sigdisc = $a;
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
    my $newn = checkfile($a, $fsuffix);
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
  use File::Copy;
  if ( checkenv() ) {
    my $PREPROC = "$JR_HOME/preproc/";
    if  ( checkdir($PREPROC) ) {
      use File::Copy;
      mustcopy("$PREPROC/m_condvar.jr",".");
    }
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

  print O "$BANNER\n";
  print O "/* for the $sd{$sigdisc} signaling discipline */\n\n";
  parse();
  print O "\n";

}

sub parse {
  scan();
  while ($tok ne "EOF") {
    if ($tok eq "ID") {
      if ($realtok eq "_monitor") {
        mmonitor();
        # not supposed to have anything afterwards,
        # so perhaps should make this an error,
        # but maybe not...
        if ($tok ne "EOF") {
            outln($realtok);
        }
      }
      elsif ($realtok =~ /^_/) {
        error("_ID found outside of monitor body");
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
      if ($realtok eq "_monitor") {
        error("_monitor found nested within _monitor");
      }
      elsif ($realtok eq "_proc") {
        mproc();
      }
      elsif ($realtok eq "_var") {
        mvar();
      }
      elsif ($realtok eq "_condvar") {
        mcondvar();
      }
      elsif ($realtok eq "_signal") {
        msignal();
      }
      elsif ($realtok eq "_signal_all") {
        msignal_all();
      }
      elsif ($realtok eq "_wait") {
        mwait();
      }
      elsif ($realtok eq "_return") {
        mreturn(0);
      }
      elsif ($realtok eq "return") {
        # disallow plain return so can use it within
        # any helper methods (i.e., non _proc) w/i monitor.
        error("within a _proc, use _return instead of return");
        mreturn(0);
      }
      elsif ($realtok eq "reply"  ||
             $realtok eq "forward" ) {
        # disallow reply and forward since don't make sense.
        error("within a proc, reply or forward not allowed");
        # treat it like a return just to keep going.
        mreturn(0);
      }
      elsif ($realtok eq "_empty") {
        mutility($realtok);
      }
      elsif ($realtok eq "_minrank") {
        mutility($realtok);
      }
      elsif ($realtok eq "_print") {
        mutility($realtok);
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

sub mmonitor {
  mustbe("ID"); # skip over _monitor
  my $classname = mustbe("ID");
  outln("class ".$classname." {");
  outln("  sem m_mutex = 1;");
  outln("  sem m_urgentq = 0;");
  outln("  int m_n_urgentq = 0;");
  outln("  String m_name;");
  outln("  public $classname(String n) {");
  outln("    this.m_name = n;");
  outln("  }");

  # this is SU code, but it works for all (m_n_urgentq == 0 for others)
  outln("  private void m_next() {");
##  outln("    try {");
  outln("      if (m_n_urgentq > 0) {");
  outln("        m_n_urgentq--;");
  outln("        V(m_urgentq);");
  outln("      }");
  outln("      else {");
  outln("        V(m_mutex);");
  outln("      }");
##  outln("    } catch (Exception oops) {oops.printStackTrace();}");
  outln("  }");
  
  block();
  out("}");
}

sub mvar {
  mustbe("ID"); # skip over _var
  out("private ");
}

sub mcondvar {
  mustbe("ID"); # skip over _condvar
  my $cvname;
  my $cnt;
  my @subs;
  ($cnt, $cvname, @subs) = cvnameandsubs();
  mustbe(";");
  if ($cnt == 0) {
    outln("private m_condvar $cvname = new m_condvar(\"$cvname\");");
  }
  else {
    my $x = "[]" x $cnt;
    out("private m_condvar $x $cvname = new m_condvar ");
    for (my $k = 0; $k < $cnt; $k++) {
      out("[$subs[$k]]");
    }
    outln(";");
    outln("  {");
    for (my $k = 0; $k < $cnt; $k++) {
      my $b = "[0]" x $k;
      outln("    for (int m_i$k = 0; m_i$k < $cvname$b.length; m_i$k++ ) {");
    }
    my $c = "";
    my $d = "";
    for (my $k = 0; $k < $cnt; $k++) {
      $c = $c . "[m_i$k]";
      $d = $d . "[\"+m_i$k+\"]";
    }
    outln("      $cvname$c = new m_condvar(\"$cvname$d\");");
    for (my $k = 0; $k < $cnt; $k++) {
      out("}");
    }
    outln("  }");
  }
}

# cv name, possibly followed by [e1][e2]...
# returns a list:
#  number of subscripts
#  name
#  subscripts
# each return value is a string of tokens,
# which are output later as needed.
sub cvnameandsubs {
  my $cvname = mustbe("ID");
  my $cnt = 0;
  my @subs;
  while ($tok eq "[") {
    $subs[$cnt] = grabmatch("[","]",1,0);
    $cnt++;
  }
  return ($cnt, $cvname, @subs);
}

sub mproc {
  mustbe("ID"); # skip over _proc
##print "start mproc\n";
  outln("public");
  my $rettype = mustbe("ID"); # grab return type
  outln($rettype);
  skip("{"); # skip over proc header
  outln("{");
##  outln("  try {");
  outln("    op void m_return_from_wait();");
  outln("    P(m_mutex);");
##print "mproc ->stuff\n";
  block();
##print "mproc <-stuff\n";
  outln("  m_next();");
##  outln("  } catch (Exception oops) {oops.printStackTrace();}");
  if ($rettype ne "void") {
    outln("throw new RuntimeException(" .
             "\"reached end of non-void _proc ($Ifile, line $.) " .
             "without executing a return\");");
  }
  outln("}");
##print "end mproc\n";
}

# generated code for all statements contains {...}
# so that these statements can appear
# as single statements to if, else, while, etc.
# e.g.,
#  if (x==2) _signal(cv);




# enclose return in an if statement to avoid unreachable code
# messages that come in case _return comes right before end of _proc.
sub mreturn {
  my $how = shift(@_); # 1 <=> SX right after _signal.
  mustbe("ID"); # skip over _return or return
  outln("{ if (true) {");
  if ($how == 1 && $sigdisc eq "-sx") {
    # msignal generated if(!x.m_signal(){ m_next(); }
    # so need only return stuff here.
  }
  else {
    outln("  m_next();");
  }
  outln("  return ");
  skip(";"); # skip over return expr
  outln(";");
  outln("}}");
}

sub msignal {
  mustbe("ID"); # skip over _signal
  my $cv = grabmatch("(",")",1,1);
  if ($sigdisc eq "-sc") {
    outln("$cv.m_signal();");
    mustbe(";");
  }
  elsif ($sigdisc eq "-sw") {
    out("{ if (");
    outln("$cv.m_signal()) {");
    outln("  P(m_mutex);");
    outln("}}");
    mustbe(";");
  }
  elsif ($sigdisc eq "-su") {
    # increment just in case we do wait.
    # if we don't, then we immediately decrement with no harm done.
    # (need to increment if we block and carefully to avoid race.)
    out("{");
    out("m_n_urgentq++;");
    out("if (");
    outln("$cv.m_signal()) {");
    outln("  P(m_urgentq);");
    outln("}");
    outln("else {");
    outln("  m_n_urgentq--;");
    outln("}");
    outln("}");
    mustbe(";");
  }
  else { # if ($sigdisc eq "-sx") {
    outln("{");
    outln("if (! ");
    outln("  $cv.m_signal()) {");
    outln("  m_next();");
    outln("}");
    outln("}");
    mustbe(";");
    # now insist that _return immediately follow _signal for -sx
    if ($realtok eq "_return") {
      mreturn(1);
    }
    elsif ($realtok eq "return") {
      # disallow plain return so can use it within
      # any helper methods (i.e., non _proc) w/i monitor.
      error("within a _proc, use _return instead of return");
      mreturn(1);
    }
    else {
      error("_signal must be followed immediately by _return " .
            "for $sd{$sigdisc} discipline");
    }
  }
}

sub msignal_all {
  if ($sigdisc ne "-sc") {
    error("_signal_all is not defined for $sd{$sigdisc} discipline");
  }
  mustbe("ID"); # skip over _signal_all
  my $cv = grabmatch("(",")",1,1);
  outln("$cv.m_signal_all();");
  mustbe(";");
}

sub mwait {
##print "start mwait\n";
  mustbe("ID"); # skip over _wait
  my $cv = grabmatch("(",")",1,1);
  outln("{  m_condvar m_cv = $cv;");
  if ($tok eq "(") {
    # prioritized wait
    my $rank = grabmatch("(",")",1,1);
    outln("  int m_r = $rank;");
    outln("  send m_cv.m_wait(m_return_from_wait,m_r);");
    outln("  send m_cv.m_wait_ranks(m_r);");
  }
  else { # yeah, could easily combine with above case, but ...
    outln("  send m_cv.m_wait(m_return_from_wait,0);");
    outln("  send m_cv.m_wait_ranks(0);");
  }
  outln("  m_next();");
  outln("  P(m_return_from_wait);");
  if ($sigdisc eq "-sc") {
    outln("  P(m_mutex);");
  }
  out("}");
  mustbe(";");
##print "end mwait\n";
}

sub mutility {
  my $which = shift(@_);
  mustbe("ID"); # skip over keyword
  my $cv = grabmatch("(",")",1,1);
  outln("$cv.m$which()");
}

