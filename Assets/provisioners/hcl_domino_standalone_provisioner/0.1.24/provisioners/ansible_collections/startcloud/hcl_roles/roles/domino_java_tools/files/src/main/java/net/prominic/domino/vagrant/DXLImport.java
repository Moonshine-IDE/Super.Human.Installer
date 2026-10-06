package net.prominic.domino.vagrant;

import java.io.File;

import lotus.domino.*;

/**
 * Import a provided DXL file into the target database.
 * This will not do any validation of the DXL.  Importing to a production database is discouraged.
 * FUTURE TASK:  Validate as XML. Use the DXL schema if available
 */
public class DXLImport {

    private static final String APP_NAME = "DXLImport";
    private static final String USAGE = "java -jar DXLImport.jar <server> <database-name> <dxl-file>";

    public static void main(String[] args) {
        Session session = null;
        try {
            System.out.println("Application '" + APP_NAME + "' started.");

			if (args.length < 3) {
				System.err.println("ERROR: Not enough arguments.");
				System.err.println("USAGE:  " + USAGE);
				System.exit(1);
			}
			String server = args[0];
			String databaseName = args[1];
			String dxlFileName = args[2];
			File dxlFile = new File(dxlFileName);
			if (!dxlFile.exists()) {
				System.err.println("DXL file not found at:  '" + dxlFile.getAbsolutePath() + ".");
				System.exit(1);
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

            importDXL(session, server, databaseName, dxlFile);


            System.out.println("names.nsf was successfully created.");


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


    public static void importDXL(Session session, String server, String databaseName, File dxlFile) throws NotesException, Exception {
		Stream stream = null;
		DxlImporter importer = null;
		Database database = null;
		
		try {
			database = session.getDatabase(server, databaseName, false);
			if (null == database || !database.isOpen()) {
				throw new Exception("Could not open database '" + database + "'.");
			}

			// https://help.hcl-software.com/dom_designer/14.0.0/basic/H_IMPORTDXL_METHOD_IMPORTER_JAVA.html
			// https://help.hcl-software.com/dom_designer/14.0.0/basic/H_EXAMPLES_NOTESDXLIMPORTER_CLASS_JAVA.html
			stream = session.createStream();
			if (stream.open(dxlFile.getAbsolutePath()) & (stream.getBytes() >0)) {
				// Import DXL from file to new database
				importer = session.createDxlImporter();
				importer.setReplaceDbProperties(true);  // allow replacing database properties
				importer.setReplicaRequiredForReplaceOrUpdate(false);  // don't require a matching replica ID in the DXL
				importer.setAclImportOption(DxlImporter.DXLIMPORTOPTION_UPDATE_ELSE_CREATE);   // Create any missing ACL entries, overwrite existing entries
				importer.setDesignImportOption(DxlImporter.DXLIMPORTOPTION_REPLACE_ELSE_CREATE);  // Create any missing design elements, overwrite existing design elements
				importer.setCompileLotusScript(true);  // Automatically compile any included LotusScript
				importer.setDocumentImportOption(DxlImporter.DXLIMPORTOPTION_REPLACE_ELSE_CREATE);   // allow importing documents.  Replace existing documents (replicaID and universal ID must match)
				importer.importDxl(stream, database);
				
				System.out.println("## Log:  " + importer.getLogComment());
				System.out.println(importer.getLog());
				System.out.println("## End Log");
				System.out.println("Imported " + importer.getImportedNoteCount() + " elements");
				// TODO: iterate over imported elements if log is insufficient
			}
        }
        finally {
            if (null != stream) {
                stream.recycle();
            }
            if (null != database) {
                database.recycle();
            }
            if (null != importer) {
                importer.recycle();
            }
        }

    }
}