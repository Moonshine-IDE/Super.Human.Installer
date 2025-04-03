package net.prominic.domino.vagrant;

import com.sun.jna.*;
import com.sun.jna.ptr.*;
import java.util.Arrays;
import java.util.Calendar;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

public interface NotesAPI extends Library {
  // Set up the library loading with proper options
  Map<String, Object> OPTIONS = new HashMap<String, Object>() {
    {
      put(Library.OPTION_CALLING_CONVENTION, Function.C_CONVENTION);
      // Add search paths for the Notes/Domino libraries
      put(Library.OPTION_OPEN_FLAGS, -1);
    }
  };

  int SECKFMGetCertifierCtx(
    String certfile,
    String password,
    PointerByReference phCertCtx,
    Pointer callback
  );
  void SECKFMFreeCertifierCtx(Pointer hCertCtx);

  // Load the library with the correct name for Linux
  NotesAPI INSTANCE = Native.load(
    Platform.isWindows() ? "nnotes" : "notes",
    NotesAPI.class,
    OPTIONS
  );

  // TIMEDATE structure from Notes API
  @Structure.FieldOrder({ "Innards" })
  public static class TIMEDATE extends Structure {

    public int[] Innards = new int[2];

    public TIMEDATE() {
      super();
    }
  }

  int REGNewServer(
    Pointer hCertCtx,
    int MakeIDType,
    String RegServer,
    String OrgUnit,
    String EntryName,
    String Password,
    String IDFileName,
    String Location,
    String Comment,
    String DomainName,
    String NetworkName,
    String AdminName,
    String ServerTitle,
    int Flags,
    short MinPasswordLength,
    Pointer signalstatus,
    Pointer ErrorPathName
  );
}
