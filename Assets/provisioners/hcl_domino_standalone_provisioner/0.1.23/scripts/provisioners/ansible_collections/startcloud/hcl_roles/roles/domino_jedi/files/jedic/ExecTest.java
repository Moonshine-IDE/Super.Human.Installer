import com.Prominic.runtime.*;

public class ExecTest {
   public static void main(String[] args) {
      String[] command = {
	 "/bin/ls",
	"/bin"
      };
      ExecTest et = new ExecTest();
      com.Prominic.runtime.NRuntime.setRuntime(new com.Prominic.runtime.DefaultUnixRuntime());
      for(int i=0;i<200;i++) {
	  new ExecThread(command,""+i,et);
/*	try {
          NProcess p = NRuntime.getRuntime().exec(command);
//	Process p = Runtime.getRuntime().exec(command);
          p.waitFor();
          System.out.println(i+": Exit code is: "+p.exitValue());
	} catch (Exception e) {
	  e.printStackTrace();
	}*/
      }
      try {
         Thread.sleep(1000);
      } catch (InterruptedException e) {}
      synchronized(et) {
        et.notifyAll();
      }
      try {
	 System.in.read();
      } catch (java.io.IOException e) {
	 e.printStackTrace();
      }
   }
   public void waitFor() throws InterruptedException {
     synchronized(this) {
       wait();
     }
}
}
