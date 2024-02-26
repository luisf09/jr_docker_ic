/*****************************************************
 * jr generated file
 ****************************************************/
import edu.ucdavis.jr.*;
import edu.ucdavis.jr.jrx.*;
import java.rmi.*;
import java.io.Serializable;

    public class JRExpresion
      extends JRjavadotlangdotObject
      implements Serializable, Cloneable
    {
	static final long serialVersionUID = 0;
	public Cap_ext_ op_done_voidTovoid;
	public Cap_ext_ JRget_op_done_voidTovoid() {
		return op_done_voidTovoid;
	}
	public void JRset_op_done_voidTovoid(Cap_ext_ op_done_voidTovoid) {
		this.op_done_voidTovoid = op_done_voidTovoid;
	}

	public Cap_ext_ op_p2_voidTovoid;
	public Cap_ext_ JRget_op_p2_voidTovoid() {
		return op_p2_voidTovoid;
	}
	public void JRset_op_p2_voidTovoid(Cap_ext_ op_p2_voidTovoid) {
		this.op_p2_voidTovoid = op_p2_voidTovoid;
	}

	public Cap_ext_ op_p1_voidTovoid;
	public Cap_ext_ JRget_op_p1_voidTovoid() {
		return op_p1_voidTovoid;
	}
	public void JRset_op_p1_voidTovoid(Cap_ext_ op_p1_voidTovoid) {
		this.op_p1_voidTovoid = op_p1_voidTovoid;
	}

	public JRExpresion(JRExpresion copy)
	{
	this.op_done_voidTovoid = copy.op_done_voidTovoid;
	this.op_p2_voidTovoid = copy.op_p2_voidTovoid;
	this.op_p1_voidTovoid = copy.op_p1_voidTovoid;

	}
	public JRExpresion(Object ... opSig)
	{
	this.op_done_voidTovoid = new Cap_ext_((Op_ext_.JRProxyOp)opSig[0]);
	this.op_p2_voidTovoid = new Cap_ext_((Op_ext_.JRProxyOp)opSig[1]);
	this.op_p1_voidTovoid = new Cap_ext_((Op_ext_.JRProxyOp)opSig[2]);

	}
	public JRExpresion(boolean dummy)	{
	    super(dummy);
	this.op_done_voidTovoid = Cap_ext_.noop;
	this.op_p2_voidTovoid = Cap_ext_.noop;
	this.op_p1_voidTovoid = Cap_ext_.noop;

	}
	public Object clone()
	    throws CloneNotSupportedException
	{
	    return super.clone();
	}
	public static Object getNoop()
	{
	    return new JRExpresion(true);
	}
    }
