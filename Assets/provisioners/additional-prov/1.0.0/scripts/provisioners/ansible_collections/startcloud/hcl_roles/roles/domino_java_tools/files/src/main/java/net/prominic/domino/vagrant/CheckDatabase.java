package net.prominic.domino.vagrant;

import java.util.Vector;

import lotus.domino.ACL;
import lotus.domino.Database;
import lotus.domino.DbDirectory;
import lotus.domino.NotesException;
import lotus.domino.NotesFactory;
import lotus.domino.NotesThread;
import lotus.domino.Session;

/**
 * Check whether this machine can access the given database on the given server.
 * If the process fails, report any errors from the Domino API
 *
 */
public class CheckDatabase {

    public static void main(String[] args) {
        if (args.length < 2) {
            System.out.println("Insufficient Arguments.  Usage: ");
            System.out.println("java -jar CheckDatabase.jar <server> <database> [acl_username]");
            System.exit(1);
        }
        String serverName = args[0];
        String databaseName = args[1];


        try {

            NotesThread.sinitThread();

            Session session = NotesFactory.createSession();
            System.out.println("Running on Notes Version: '" + session.getNotesVersion() + "'.");

			// read a user to check against the ACL
			String testUser = session.getUserName();  // check the running user
			if (args.length >= 3) {
				testUser = args[2];
			}

            checkServer(session, serverName);

            Database database = session.getDatabase(serverName, databaseName, false);
            try {
                if (null == database || !database.isOpen()) {
                    throw new Exception("Could not open database.");
                }
                String actualServerName = session.getServerName(); //session.getServerName();
                String databaseTitle = database.getTitle();
                System.out.println("SUCCESSFUL!");
                System.out.println("Server: '" + actualServerName + "', Database: '" + databaseTitle + "'.");

                checkACLAccess(database, testUser);
            }
            finally {
                if (null != database) {
                    database.recycle();
                    database = null;
                }
                session.recycle();
            }
        }
        catch (Throwable throwable) {
            System.out.println("FAILED!");
            throwable.printStackTrace();
        }
        finally {
            NotesThread.stermThread();
        }
    }


    public static void checkServer(Session session, String serverName) throws NotesException, Exception {
        DbDirectory directory = null;
        Database database = null;
        try {

            directory = session.getDbDirectory(serverName);
            if (null == directory) {
                throw new Exception("Unable to open directory for server '" + serverName + "'.");
            }
            else {
//                System.out.println("Successfully opened directory for server '" + serverName + "'.");

                database = directory.getFirstDatabase(DbDirectory.DATABASE);
                if (null == database) {
                    throw new Exception("Unable to open database for server '" + serverName + "'.");
                }
                else {
                    System.out.println("The first database on server '" + serverName + "' was '" + database.getTitle() + "'.");
                }

            }

        }
        catch (NotesException ex) {
            throw new Exception("Unable to open server '" + serverName + "': '" + ex.text + "'.");
        }
        finally {
            if (null != database) { database.recycle(); }
            if (null != directory) { directory.recycle(); }
        }
    }

    public static void checkACLAccess(Database database, String testUser) {
        try {
            //String title = database.getTitle();
            int accLevel = database.queryAccess(testUser);
            String accessStr = null;
            switch (accLevel) {
                case(ACL.LEVEL_NOACCESS) :
                    accessStr = "none";
                    break;
                case(ACL.LEVEL_DEPOSITOR) :
                    accessStr = "depositor";
                    break;
                case(ACL.LEVEL_READER) :
                    accessStr = "reader";
                    break;
                case(ACL.LEVEL_AUTHOR) :
                    accessStr = "author";
                    break;
                case(ACL.LEVEL_EDITOR) :
                    accessStr = "editor";
                    break;
                case(ACL.LEVEL_DESIGNER) :
                    accessStr = "designer";
                    break;
                case(ACL.LEVEL_MANAGER) :
                    accessStr = "manager";
                    break;
                default:
                    accessStr = "unknown";
                    break;
            }
            System.out.println("User '"+ testUser + "' has '" + accessStr + "' access to this database.");

            System.out.println("Privileges: ");
            int accPriv = database.queryAccessPrivileges(testUser);
            // Check each privilege bit to see if it is 0 or 1
            if ((accPriv & Database.DBACL_CREATE_DOCS) > 0)
                System.out.println("\tCreate documents");
            if ((accPriv & Database.DBACL_DELETE_DOCS) > 0)
                System.out.println("\tDelete documents");
            if ((accPriv & Database.DBACL_CREATE_PRIV_AGENTS) > 0)
                System.out.println("\tCreate private agents");
            if ((accPriv & Database.DBACL_CREATE_PRIV_FOLDERS_VIEWS) > 0)
                System.out.println("\tCreate private folders/views");
            if ((accPriv & Database.DBACL_CREATE_SHARED_FOLDERS_VIEWS) > 0)
                System.out.println("\tCreate shared folders/views");
            if ((accPriv & Database.DBACL_CREATE_SCRIPT_AGENTS) > 0)
                System.out.println("\tCreate LotusScript/Java agents");
            if ((accPriv & Database.DBACL_READ_PUBLIC_DOCS) > 0)
                System.out.println("\tRead public documents");
            if ((accPriv & Database.DBACL_WRITE_PUBLIC_DOCS) > 0)
                System.out.println("\tWrite public documents");
            if ((accPriv & Database.DBACL_REPLICATE_COPY_DOCS) > 0)
                System.out.println("\tReplicate or copy documents");

            Vector roles = database.queryAccessRoles(testUser);
            if (roles.size() == 0) {
                System.out.println("No roles");
            }
            else {
                System.out.println("Roles:");
                for (int i = 0; i < roles.size(); i++) {
                    System.out.println("\t" + roles.elementAt(i));
                }
            }


        }
        catch (Exception ex) {
            System.out.println("Could not read access level.");
            ex.printStackTrace();
        }
    }

}
