import com.Prominic.runtime.*;
import java.io.IOException;

public class ExecThread extends Thread {
   private String[] command;
   private ExecTest sync;
   public ExecThread(String[] command, String id,ExecTest sync) {
      this.command = command;
      setPriority(Thread.MIN_PRIORITY);
      setName(id);
      this.sync = sync;
      start();
   }
   public void run() {
      System.out.println(getName()+": Executing command.");
      try {
	 sync.waitFor();
	 NProcess p = NRuntime.getRuntime().exec(command);
//	Process p = Runtime.getRuntime().exec(command);
	 p.waitFor();
//	for(int i=0;i<10000;i++) yield();
      } catch (InterruptedException e) {
	 System.out.println(getName()+": interrupted.");
      } catch (Exception e) {
	 System.out.println(getName()+": IOException.");
	 e.printStackTrace();
      }
      System.out.println(getName()+": done.");
   }
}
