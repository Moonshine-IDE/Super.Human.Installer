package net.prominic.domino.vagrant;

import com.mindoo.domino.jna.internal.Mem32;
import com.mindoo.domino.jna.internal.Mem64;
import com.mindoo.domino.jna.internal.NotesConstants;
import com.mindoo.domino.jna.internal.NotesNativeAPI;
import com.mindoo.domino.jna.internal.NotesNativeAPI32;
import com.mindoo.domino.jna.internal.NotesNativeAPI64;
import com.mindoo.domino.jna.internal.structs.KFM_PASSWORDStruct;
import com.mindoo.domino.jna.utils.NotesStringUtils;
import com.mindoo.domino.jna.utils.PlatformUtils;
import com.sun.jna.*;
import com.sun.jna.ptr.*;
import lotus.domino.DateTime;
import lotus.domino.NotesException;
import lotus.domino.Registration;
import lotus.domino.Session;

public class HybridServerRegistration {

  // Add KFM constants from reg.h
  public static final int KFM_IDFILE_TYPE_FLAT = 0;
  public static final int KFM_IDFILE_TYPE_STD = 1;
  public static final int KFM_IDFILE_TYPE_DERIVED = 2;

  public static boolean registerServer(
    Session session,
    String certifierFile,
    String certifierPassword,
    String entryName,
    String idFileName,
    String domainName,
    String adminName,
    String serverTitle
  ) throws NotesException {
    DateTime dt = null;
    Registration reg = null;

    try {
      // Validate parameters
      if (session == null) throw new IllegalArgumentException(
        "Session cannot be null"
      );
      if (
        certifierFile == null || certifierFile.trim().isEmpty()
      ) throw new IllegalArgumentException("Certifier file is required");
      if (
        entryName == null || entryName.trim().isEmpty()
      ) throw new IllegalArgumentException("Server name is required");

      System.out.println("Getting certifier context from: " + certifierFile);

      // Create password structure
      Memory certPWMem = NotesStringUtils.toLMBCS(certifierPassword, true);
      KFM_PASSWORDStruct.ByReference kfmPwd = KFM_PASSWORDStruct.newInstanceByReference();
      NotesNativeAPI.get().SECKFMCreatePassword(certPWMem, kfmPwd);

      // Convert paths to LMBCS
      Memory certFilePathMem = NotesStringUtils.toLMBCS(certifierFile, true);
      Memory retCertNameMem = new Memory(NotesConstants.MAXUSERNAME);
      ShortByReference retfIsHierarchical = new ShortByReference();
      ShortByReference retwFileVersion = new ShortByReference();

      // Get certifier context based on platform
      int result;
      Object hKfmCertCtx = null;

      if (PlatformUtils.is64Bit()) {
        LongByReference rethKfmCertCtx = new LongByReference();
        result =
          NotesNativeAPI64
            .get()
            .SECKFMGetCertifierCtx(
              certFilePathMem,
              kfmPwd,
              null, // certLogPath not needed
              null, // expiration not needed
              retCertNameMem,
              rethKfmCertCtx,
              retfIsHierarchical,
              retwFileVersion
            );

        if (result != 0) {
          System.out.println(
            "Failed to get certifier context. Error: " + result
          );
          return false;
        }

        hKfmCertCtx = rethKfmCertCtx.getValue();
      } else {
        IntByReference rethKfmCertCtx = new IntByReference();
        result =
          NotesNativeAPI32
            .get()
            .SECKFMGetCertifierCtx(
              certFilePathMem,
              kfmPwd,
              null, // certLogPath not needed
              null, // expiration not needed
              retCertNameMem,
              rethKfmCertCtx,
              retfIsHierarchical,
              retwFileVersion
            );

        if (result != 0) {
          System.out.println(
            "Failed to get certifier context. Error: " + result
          );
          return false;
        }

        hKfmCertCtx = rethKfmCertCtx.getValue();
      }

      if (
        hKfmCertCtx == null ||
        (
          PlatformUtils.is64Bit()
            ? ((Long) hKfmCertCtx) == 0L
            : ((Integer) hKfmCertCtx) == 0
        )
      ) {
        throw new NotesException(
          0,
          "Received null handle creating a certifier context"
        );
      }
      Pointer certCtxPointer = null;
      try {
        // Set up registration parameters
        String serverPassword = "";
        short minPasswordLength = (short) 0;

        int flags =
          DirectServerRegistration.fREGCreateIDFileNow |
          DirectServerRegistration.fREGUSARequested |
          DirectServerRegistration.fREGCreateAddrBookEntry |
          DirectServerRegistration.fREGOkayToModifyID;

        // Before calling REGNewServer, convert the handle to a Pointer

        if (PlatformUtils.is64Bit()) {
          certCtxPointer = new Pointer((Long) hKfmCertCtx);
        } else {
          certCtxPointer = new Pointer(((Integer) hKfmCertCtx).longValue());
        }

        // Then use this pointer in both the REGNewServer call and cleanup
        result =
          NotesAPI.INSTANCE.REGNewServer(
            certCtxPointer, // Use the converted pointer
            DirectServerRegistration.KFM_IDFILE_TYPE_STD,
            "",
            null,
            entryName,
            serverPassword,
            idFileName,
            null,
            null,
            domainName,
            null,
            adminName,
            serverTitle,
            flags,
            minPasswordLength,
            null,
            null
          );

        if (result != 0) {
          System.out.println(
            "Server registration failed with error code: " + result
          );
          return false;
        }

        System.out.println("Server registration completed successfully");
        return true;
      } finally {
        // Free the certifier context

        // In the finally block, use the same pointer
        if (hKfmCertCtx != null) {
          NotesAPI.INSTANCE.SECKFMFreeCertifierCtx(certCtxPointer);
        }
      }
    } catch (Exception e) {
      System.out.println("Error during registration: " + e.getMessage());
      e.printStackTrace();
      throw new NotesException(0, "Registration failed: " + e.getMessage());
    } finally {
      // Clean up Notes objects
      try {
        if (dt != null) dt.recycle();
        if (reg != null) reg.recycle();
      } catch (Exception e) {
        System.out.println("Error during cleanup: " + e.getMessage());
      }
    }
  }
}
