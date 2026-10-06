package net.prominic.domino.vagrant;

import lotus.domino.NotesException;
import lotus.domino.NotesFactory;
import lotus.domino.NotesThread;
import lotus.domino.Session;
import lotus.domino.IDVault;

/**
 * Upload a user ID file to the Domino ID Vault.
 * The user must first be added into ID Vault by policy.
 */
public class PushUserIDtoIDVault {

    public static void main(String[] args) {
        if (args.length < 4) {
            System.out.println("Insufficient Arguments. Usage: ");
            System.out.println("java -jar PushUserIDtoIDVault.jar <id_file_path> <username> <password> <server_name>");
            System.exit(1);
        }

        String idFilePath = args[0];
        String username = args[1];
        String password = args[2];
        String serverName = args[3];

        try {
            NotesThread.sinitThread();
            Session session = NotesFactory.createSession();
            System.out.println("Running on Notes Version: '" + session.getNotesVersion() + "'.");

            uploadIDToVault(session, idFilePath, username, password, serverName);
        }
        catch (Throwable throwable) {
            System.out.println("FAILED!");
            throwable.printStackTrace();
        }
        finally {
            NotesThread.stermThread();
        }
    }

    public static void uploadIDToVault(Session session, String idFilePath, String username, String password, String serverName) 
            throws NotesException {
        IDVault idVault = null;
        try {
            idVault = session.getIDVault();
            if (idVault == null) {
                throw new Exception("Unable to access ID Vault.");
            }

            // Check if ID is already in vault
            boolean isInVault = idVault.isIDInVault(username, serverName);
            if (isInVault) {
                System.out.println("ID for user '" + username + "' is already in the vault. Attempting to sync...");
                idVault.syncUserIDFile(idFilePath, username, password, serverName);
                System.out.println("Successfully synchronized ID in vault.");
            } else {
                System.out.println("Uploading ID for user '" + username + "' to vault...");
                idVault.putUserIDFile(idFilePath, username, password, serverName);
                System.out.println("Successfully uploaded ID to vault.");
            }

            // Verify the ID is now in the vault
            if (idVault.isIDInVault(username, serverName)) {
                String vaultServer = idVault.getServerName();
                System.out.println("SUCCESSFUL!");
                System.out.println("ID for user '" + username + "' is confirmed to be in the vault on server '" + vaultServer + "'.");
            } else {
                throw new Exception("Failed to verify ID in vault after upload/sync operation.");
            }
        }
        catch (NotesException ex) {
            System.out.println("FAILED!");
            System.out.println("Notes Error: " + ex.text);
            throw ex;
        }
        catch (Exception ex) {
            System.out.println("FAILED!");
            System.out.println("Error: " + ex.getMessage());
            throw new NotesException(0, ex.getMessage());
        }
        finally {
            if (idVault != null) {
                try {
                    idVault.recycle();
                } catch (NotesException e) {
                    // Ignore recycling errors
                }
            }
            try {
                session.recycle();
            } catch (NotesException e) {
                // Ignore recycling errors
            }
        }
    }
}
