package net.prominic.domino.vagrant;

import com.sun.jna.*;
import com.sun.jna.ptr.*;
import java.util.Arrays;
import java.util.Calendar;
import java.util.List;

public class DirectServerRegistration {

  // Constants from reg.h
  public static final short KFM_IDFILE_TYPE_STD = 1;
  public static final int fREGCreateIDFileNow = 0x0001;
  public static final int fREGUSARequested = 0x0002;
  public static final int fREGCreateAddrBookEntry = 0x0008;
  public static final int fREGOkayToModifyID = 0x0010;

  static {
    // Set up the library path for Linux
    if (!Platform.isWindows()) {
      String notesPath = System.getenv("LD_LIBRARY_PATH");
      if (notesPath != null && !notesPath.isEmpty()) {
        System.setProperty("jna.library.path", notesPath);
      }
    }
  }

  public static boolean registerServer(
    String entryName,
    String idFileName,
    String domainName,
    String adminName,
    String serverTitle
  ) {
    try {
      System.out.println("Attempting to register server using Notes API");
      System.out.println(
        "Library path: " + System.getProperty("jna.library.path")
      );

      // Set required flags
      int flags =
        fREGCreateIDFileNow |
        fREGUSARequested |
        fREGCreateAddrBookEntry |
        fREGOkayToModifyID;

      // Validate required parameters
      if (entryName == null || entryName.trim().isEmpty()) {
        throw new IllegalArgumentException(
          "Server name (entryName) is required"
        );
      }
      if (idFileName == null || idFileName.trim().isEmpty()) {
        throw new IllegalArgumentException("ID file name is required");
      }
      if (domainName == null || domainName.trim().isEmpty()) {
        throw new IllegalArgumentException("Domain name is required");
      }

      System.out.println("Registering server with parameters:");
      System.out.println("- Server Name: " + entryName);
      System.out.println("- ID File: " + idFileName);
      System.out.println("- Domain: " + domainName);
      System.out.println("- Admin: " + adminName);
      System.out.println("- Title: " + serverTitle);

      // Create a default password if none is specified
      String defaultPassword = "notespassword";
      short minPasswordLength = (short) defaultPassword.length();

      // Call the C API directly with all required parameters
      int result = NotesAPI.INSTANCE.REGNewServer(
        Pointer.NULL, // hCertCtx - can be null when using local registration
        KFM_IDFILE_TYPE_STD, // MakeIDType - using standard hierarchical
        "", // RegServer - empty string for local server
        null, // OrgUnit - optional
        entryName, // EntryName - required
        defaultPassword, // Password - providing default password
        idFileName, // IDFileName - required
        "", // Location - empty string instead of null
        "", // Comment - empty string instead of null
        domainName, // DomainName - required
        "", // NetworkName - empty string instead of null
        adminName, // AdminName
        serverTitle, // ServerTitle
        flags, // Flags
        minPasswordLength, // MinPasswordLength - matching default password length
        null, // signalstatus - optional
        null // ErrorPathName - optional
      );

      if (result != 0) {
        System.out.println("Registration failed with error code: " + result);
        return false;
      }

      System.out.println("Server registration completed successfully");
      return true;
    } catch (Exception e) {
      e.printStackTrace();
      System.out.println("Error during server registration: " + e.getMessage());
      return false;
    }
  }
}
