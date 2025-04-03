package net.prominic.domino.vagrant;

import java.io.File;

import lotus.domino.*;


public class CreateNamesDatabase {

    private static final String APP_NAME = "CreateNamesDatabase";

    public static void main(String[] args) {
        Session session = null;
        try {
            System.out.println("Application '" + APP_NAME + "' started.");

            // Check for names.nsf at hard-code path
            if (new File("/local/notesdata/names.nsf").exists()) {
                System.out.println("ERROR: names.nsf already exists.");
                System.exit(-1);
            }


            NotesThread.sinitThread();

            // If a password is available on the command line, use that when creating the session
            String password = System.getenv("PASSWORD");
            if (null == password || password.trim().isEmpty()) {
                System.out.println("No password found.");
                session = NotesFactory.createSession();
            }
            else {
                System.out.println("Password found.");
                session = NotesFactory.createSession((String)null, (String)null, password);
            }
            System.out.println("Running as user: '" + session.getUserName() + "'.");

            createLocalNamesDatabase(session);


            System.out.println("names.nsf was successfully created.");


        }
        catch (Throwable throwable) {
            throwable.printStackTrace();
        }
        finally {
            try {
                if (null != session) {
                    session.recycle();
                }
            }
            catch(NotesException ex) {
                ex.printStackTrace();
            }
            NotesThread.stermThread();
            System.out.println("Application '" + APP_NAME + "' completed.");
        }
    }


    public static void createLocalNamesDatabase(Session session) throws NotesException, Exception {
        Database template = null;
        Database localNames = null;

        try {

            // need to use the full path for the template when running in the Domino environment
            //template = session.getDatabase("", "/local/notesdata/pubnames.ntf", false);
            //template = session.getDatabase("", "pubnames.ntf", false);
            template = session.getDatabase("", "pernames.ntf", false);
            //template = session.getDatabase("domino-49.prominic.net", "pubnames.ntf", false);
            if (null == template || !template.isOpen()) {
                throw new Exception("Could not open template.");
            }

            // Create a local names.nsf.  Don't inherit changes
            localNames = template.createFromTemplate("", "names.nsf", false);
            // use an absolute path so that it is created in the data directory
            //localNames = template.createFromTemplate("", "/local/notesdata/names.nsf", false);
            if (null == localNames || !localNames.isOpen()) {
                throw new Exception("Could not open new names.nsf.");
            }
        }
        finally {
            if (null != localNames) {
                localNames.recycle();
            }
            if (null != template) {
                template.recycle();
            }
        }

    }
}