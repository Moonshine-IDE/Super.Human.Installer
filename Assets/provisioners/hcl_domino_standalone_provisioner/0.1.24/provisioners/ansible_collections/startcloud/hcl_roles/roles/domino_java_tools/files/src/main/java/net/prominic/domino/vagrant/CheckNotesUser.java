package net.prominic.domino.vagrant;

import lotus.domino.*;

/**
 * Display some information to help debug the Notes user
 * @author joelanderson
 *
 */
public class CheckNotesUser {

    public static void main(String[] args) {
        try {
            String notesIDPath = null;
            if (args.length >= 1) {
                notesIDPath = args[0];
            }
            String databaseName = null;
            if (args.length >= 2) {
                databaseName = args[1];
            }
            String docID = null;
            if (args.length >= 3) {
                docID = args[2];
            }

            checkNotesUser(notesIDPath, databaseName, docID);
        }
        catch (Throwable throwable) {
            throwable.printStackTrace();
        }

    }

    /**
     * Display some information to help debug the Notes user.
     * @param notesIDPath  The path to the NotesID file
     * @param databaseName  The path and name of the local database to use for the signing check
     * @param docID  the universal ID of the Document to sign
     * @throws Exception
     */
    public static void checkNotesUser(String notesIDPath, String databaseName, String docID) throws Exception {
        try {
            NotesThread.sinitThread();

            // build the session arguments
            String[] args = null;
            if (null == notesIDPath || notesIDPath.trim().equals("")) {
                System.out.println("Using default notesID path.");
                args = new String[0];
            }
            else {
                System.out.println("Using the passed NotesID path '" + notesIDPath + "'.");
                args = new String[1];
                args[0] = "=" + notesIDPath;
            }

//            Session session = NotesFactory.createSession("localhost", args, "", "");
            Session session = NotesFactory.createSession(null, args, null, null);
            System.out.println("Running on Notes Version: '" + session.getNotesVersion() + "'.");


            // start running tests with the session

            String username = session.getUserName();
            System.out.println("Notes User Name: '" + username + "'.");

            // user-friendly name
            Name userNameObject = session.getUserNameObject();
            try {
                String outputName = userNameObject.getAbbreviated();
                System.out.println("Cleaned-up Notes User Name: '" + outputName + "'.");
            }
            finally {
                if (null != userNameObject) {
                    userNameObject.recycle();
                    userNameObject = null;
                }
            }


            if (null != databaseName && !databaseName.trim().equals("")) {

                Database database = session.getDatabase("", databaseName, false);
                Document document = null;
                try {
                    if (null == database || !database.isOpen()) {
                        throw new Exception("Could not open database '" + databaseName + "'.");
                    }
                    if (null == docID || docID.trim().equals("")) {
                        System.out.println("Testing a database sign operation.");
                        database.sign();
                    }
                    else {
                        document = database.getDocumentByUNID(docID);
                        if (null == document) {
                            throw new Exception("Could not find document with ID '" + docID + "' in database '" + database + "'.");
                        }
                        System.out.println("Testing a document sign operation on a '" +
                                           document.getItemValueString("Form") + "' document.");
                        document.sign();
                    }
                }
                finally {
                    if (null != database) {
                        database.recycle();
                        database = null;
                    }
                    if (null != document) {
                        document.recycle();
                        document = null;
                    }
                }
            }
        }
        catch (Throwable ex) {
        		ex.printStackTrace();
        		throw ex;
        }
        finally {
            NotesThread.stermThread();
        }

    }

}
