package net.prominic.domino.vagrant;

import java.io.File;

import lotus.domino.*;

/**
 * Create a blank database that may be used for DXL imports
 */
public class CreateDatabase {

    private static final String APP_NAME = "CreateDatabase";
    private static final String USAGE = "java -jar CreateDatabase.jar <server> <database-name>";

    public static void main(String[] args) {
        Session session = null;
        try {
            System.out.println("Application '" + APP_NAME + "' started.");

			if (args.length < 2) {
				System.err.println("ERROR: Not enough arguments.");
				System.err.println("USAGE:  " + USAGE);
				System.exit(1);
			}
			String server = args[0];
			String databaseName = args[1];


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

            createDatabase(session, server, databaseName);


            System.out.println(databaseName + " is ready for use.");


        }
        catch (Throwable throwable) {
            throwable.printStackTrace();
            System.exit(1);  // trigger an error for scripting
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


    public static void createDatabase(Session session, String server, String databaseName) throws NotesException, Exception {
		DbDirectory dbDirectory = null;
		Database database = null;
		ACL acl = null;
		View defaultView = null;
		
		try {
			// Check if the database already exists
			database = session.getDatabase(server, databaseName, false);  
			if (null != database) {
				System.out.println("Database '" + databaseName + "' already exists.  Skipping..."); 
				return;
				// TODO:  delete instead?
			}
        	
        		// NOTE: The database could also be created from a template.  See CreateNamesDatabase for an example.

        		// Create with DBDirectory:  https://help.hcl-software.com/dom_designer/14.0.0/basic/H_CREATE_METHOD_JAVA.html
        		// If "" is used for the server the database will be created in the directory configured in notes.ini
            dbDirectory = session.getDbDirectory(server);
            // The second parameter will open the database so that more options may be run.
            System.out.println("Creating Database '" + databaseName + "'.");
            database = dbDirectory.createDatabase(databaseName, true);
            // The database is blank, with no forms or views
            // TODO:  Describe the default ACL
            
            // At least one view is required to open the database. 
            System.out.println("Creating default view");
            // check for a duplicate if I run against an existing database
            defaultView = database.createView();   // Default is "(default)", SELECT @All, single column for @DocNumber
            
            // For the title, use the database name, but strip the directory and extension
            String title = databaseName;
            int index = title.lastIndexOf('.');
            if (index >= 0) {
            		title = title.substring(0, index);
            }
            index = title.lastIndexOf("/");
            if (index < 0) { // no match
            		index = title.lastIndexOf("\\");  // try backslash instead
        		}
        		if (index >= 0) {
        			title = title.substring(index + 1);
        		}
            System.out.println("Setting title to '" + title + "'.");
            database.setTitle(title);
            
            // Update the ACL
            // Update default to allow user access from Notes or Designer
            // TODO: support user ID
            System.out.println("Setting ACL for database '" + databaseName + "'.");
            acl = database.getACL();
            ACLEntry defaultEntry = acl.getEntry("-Default-");
            if (null == defaultEntry) {
            		defaultEntry = acl.createACLEntry("-Default-", ACL.LEVEL_MANAGER);
            }
            ACLEntry anonymousEntry = acl.getEntry("Anonymous");
            if (null == anonymousEntry) {
            		anonymousEntry = acl.createACLEntry("Anonymous", ACL.LEVEL_EDITOR);   // this should be sufficient for most agents
            		anonymousEntry.setUserType(ACLEntry.TYPE_PERSON);
            		// minimal roles for agent - included in EDITOR
            		// anonymousEntry.setPublicReader(true);
            		// anonymousEntry.setPublicWriter(true);
            		// anonymousEntry.setCanReplicateOrCopyDocuments(true); 
            }
            
        }
        finally {
            if (null != database) {
                database.recycle();
            }
            if (null != dbDirectory) {
                dbDirectory.recycle();
            }
        }

    }
}