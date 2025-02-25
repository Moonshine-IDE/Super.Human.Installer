package net.prominic.domino.vagrant;

import com.ibm.domino.napi.c.xsp.XSPNative;
import com.mindoo.domino.jna.errors.NotesError;
import com.mindoo.domino.jna.gc.NotesGC;
import com.mindoo.domino.jna.utils.IDUtils;
import com.mindoo.domino.jna.utils.LegacyAPIUtils;
import com.mindoo.domino.jna.utils.NotesIniUtils;
import com.mindoo.domino.jna.utils.NotesInitUtils;
import com.mindoo.domino.jna.utils.NotesNamingUtils.Privileges;
import java.io.BufferedReader;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileReader;
import java.time.LocalDateTime;
import java.util.EnumSet;
import java.util.Properties;
import java.util.concurrent.Callable;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import lotus.domino.DateTime;
import lotus.domino.NotesException;
import lotus.domino.NotesFactory;
import lotus.domino.NotesThread;
import lotus.domino.Registration;
import lotus.domino.Session;
import org.json.JSONObject;
import org.json.JSONTokener;

/**
 * Register and additional Domino server from the local server.
 * Expected to run on a hcl_domino_standalone_provisioner Vagrant instance.
 * @see https://help.hcltechsw.com/dom_designer/12.0.2/basic/H_EXAMPLE_REGISTERNEWSERVER_METHOD_JAVA.html
 */
public class CreateAdditionalServerJNA {

  private static final String APP_NAME = "CreateAdditionalServerJNA";

  /** Reuse the generated properties file for CrossCertifyNotesID by default */
  protected static final String DEFAULT_PROPERTIES_FILE =
    "CrossCertifyNotesID.properties";
  protected static String dataDirectory = null;
  protected static String certID = null;
  protected static String hostServerIDFilePath = null;
  protected static String settingsFile = null;
  // protected static String aclTemplate = null;
  protected static boolean debugMode = true;

  public static void main(String[] args) {
    FileInputStream fis = null;
    try {
      System.out.println("Application '" + APP_NAME + "' started.");

      loadSharedProperties();

      // The JSON file used for Domino server setup can also be used for for this configuration
      fis = new FileInputStream(settingsFile);
      JSONObject json = (JSONObject) new JSONTokener(fis).nextValue();
      JSONObject serverSetup = json.getJSONObject("serverSetup");
      JSONObject serverConfig = serverSetup.getJSONObject("server");

      // Arguments:
      if (args.length < 1) {
        throw new Exception(
          "No properties file specified for the additional server."
        );
      }
      String additionalServerPropertiesFileName = args[0];
      File additionalServerPropertiesFile = new File(
        additionalServerPropertiesFileName
      );
      if (!additionalServerPropertiesFile.exists()) {
        throw new Exception(
          "Could not find file '" + additionalServerPropertiesFileName + "'."
        );
      }
      log(
        "Loading additional server properties:  '" +
        additionalServerPropertiesFile.getAbsolutePath() +
        "'."
      );
      Properties additionalServerProperties = new Properties();
      try {
        fis = new FileInputStream(additionalServerPropertiesFile);
        additionalServerProperties.load(fis);
      } catch (Exception ex) {
        throw new Exception(
          "Could not load properties file '" +
          additionalServerPropertiesFile.getAbsolutePath() +
          "'."
        );
      } finally {
        if (null != fis) {
          try {
            fis.close();
          } catch (Exception ex) {
            // ignore
          }
        }
      }

      // TODO:  load properties and verify they are non-empty.  Allow defaults as appropriate
      String additionalServerName = readRequiredProperty(
        additionalServerProperties,
        "server.name"
      );
      String additionalServerPassword = additionalServerProperties.getProperty(
        "server.id.password",
        ""
      ); // password is allowed to be empty
      String additionalServerTitle = readRequiredProperty(
        additionalServerProperties,
        "server.id.title"
      );
      String outputIDFile = readRequiredProperty(
        additionalServerProperties,
        "server.id.output"
      );

      // Read from server configuration:

      String hostServerIDPassword = "password";
      String domainName = serverConfig.getString("domainName");
      String serverAdministrator = getServerAdmin(); // use local server admin
      String registrationServer = serverConfig.getString("name");
      String certIDPassword = serverSetup
        .getJSONObject("org")
        .getString("certifierPassword"); // not in original steps below

      if (additionalServerPassword == null) {
        additionalServerPassword = "";
      }

      log("additionalServerPassword len: " + additionalServerPassword.length());
      
      // validation
      if (null == hostServerIDFilePath || hostServerIDFilePath.trim().isEmpty() || !new File(hostServerIDFilePath).exists()) {
      	System.err.println("Invalid server.id path:  '" + hostServerIDFilePath + "'.");
      	System.exit(1);
      }
      if (null == certID || certID.trim().isEmpty() || !new File(certID).exists()) {
      	System.err.println("Invalid cert ID path:  '" + certID + "'.");
      	System.exit(1);
      }
      if (null == outputIDFile || outputIDFile.trim().isEmpty() || !new File(outputIDFile).getParentFile().exists()) {
      	System.err.println("Invalid output path:  '" + outputIDFile + "'.");
      	System.exit(1);
      }

      createAdditionalServer(
        hostServerIDFilePath,
        hostServerIDPassword,
        certID,
        certIDPassword,
        registrationServer,
        additionalServerName,
        additionalServerPassword,
        additionalServerTitle,
        outputIDFile,
        domainName
      );
    } catch (Throwable throwable) {
      throwable.printStackTrace();
    } finally {
      try {
        if (null != fis) {
          fis.close();
        }
      } catch (Exception ex) {
        ex.printStackTrace();
      }

      System.out.println("Application '" + APP_NAME + "' completed.");
    }
  }

  private static lotus.domino.DateTime dt = null;
  private static lotus.domino.Session session = null;
  private static lotus.domino.Registration reg = null;

  public static Boolean createAdditionalServer(
    String hostServerIDFilePath,
    String hostServerIDPassword,
    String hostCertIDFilePath,
    String hostCertIDPassword,
    String hostServerName,
    String addtionalServerName,
    String addtionalServerPassword,
    String addtionalServerTitle,
    String addtionalServerIDStorePath,
    String addtionalServerDomainName
  ) {
    try {
      //initial Notes/Domino access for current thread (running single-threaded here)
      NotesThread.sinitThread();

      //launch run method within runWithAutoGC block to let it collect/dispose C handles
      NotesGC.runWithAutoGC(
        new Callable<Object>() {
          public Object call() throws Exception {
            // use IDUtils.switchToId if you want to unlock the ID file and switch the current process
            // to this ID; should only be used in standalone applications
            // if this is missing, you will be prompted for your ID password the first time the
            // id certs are required

            NotesGC.setPreferNotesTimeDate(true);
            if (
              addtionalServerName != null && addtionalServerPassword != null
            ) {
              System.out.println(
                "Additional Server Name: " + addtionalServerName
              );
              System.out.println(
                "Additional Server Title: " + addtionalServerTitle
              );

              System.out.println(
                "hostServerIDFilePath: " + hostServerIDFilePath
              );
              System.out.println(
                "addtionalServerIDStorePath: " + addtionalServerIDStorePath
              );
              IDUtils.switchToId(
                hostServerIDFilePath,
                hostServerIDPassword,
                false
              );

              String currentUser = IDUtils.getIdUsername();
              System.out.println(
                "Switched to ID: " + hostServerIDFilePath + ":" + currentUser
              );

              session = NotesFactory.createSessionWithFullAccess();

              if (session != null) {
                System.out.println(
                  "session username: " + session.getUserName()
                );

                if (addtionalServerName != null) {
                  HybridServerRegistration.registerServer(
                    session,
                    hostCertIDFilePath,
                    hostCertIDPassword,
                    addtionalServerName,
                    addtionalServerIDStorePath,
                    addtionalServerDomainName,
                    currentUser,
                    addtionalServerTitle
                  );
                }
              } else {
                System.out.println("Could not get session.");
                return false;
              }
            }
            return true;
          }
        }
      );
    } catch (NotesError e) {
      e.printStackTrace();

      System.out.println("NotesError 107:" + e.getMessage());
      return false;
    } catch (java.lang.Exception e) {
      e.printStackTrace();

      System.out.println("Exception 111:" + e.getMessage());
      return false;
    } finally {
      //terminate Notes/Domino access for current thread
      try {
        if (null != dt) {
          dt.recycle();
        }
        if (null != reg) {
          reg.recycle();
        }
        if (null != session) {
          session.recycle();
        }
      } catch (lotus.domino.NotesException e) {
        e.printStackTrace();
        System.out.println("Exception 246:" + e.getMessage());
      }
      NotesThread.stermThread();
    }
    return true;
  }

  /**
   * Load the application properties, from the first available source here:<ul>
   *   <li>The file configured by the <code>app.properties.file</code> property (set with <code>-Dapp.properties.file=%file%</code>)</li>
   *   <li>The default file: <code>./CrossCertifyNotesID.properties</code>
   *   <li>Default values defined in this class.
   * </ul>
   */
  public static void loadSharedProperties() {
    String propertiesFileName = System.getProperty("app.properties.file");
    debug("propertiesFileName='" + propertiesFileName + "'.");
    if (null == propertiesFileName || propertiesFileName.isEmpty()) {
      propertiesFileName = DEFAULT_PROPERTIES_FILE;
    }

    Properties properties = new Properties();
    File propertiesFile = new File(propertiesFileName);
    if (propertiesFile.exists()) {
      log(
        "Loading properties file '" + propertiesFile.getAbsolutePath() + "'."
      );
      FileInputStream fis = null;
      try {
        fis = new FileInputStream(propertiesFile);
        properties.load(fis);
      } catch (Exception ex) {
        log(
          "Could not load properties file '" +
          propertiesFile.getAbsolutePath() +
          "'.  Using defaults..."
        );
      } finally {
        if (null != fis) {
          try {
            fis.close();
          } catch (Exception ex) {
            // ignore
          }
        }
      }
    } else {
      log(
        "Properties file '" +
        propertiesFile.getAbsolutePath() +
        "' does not exist.  Using defaults..."
      );
    }

    // read the properties
    dataDirectory =
      properties.getProperty("data.directory", "/local/notesdata");
    settingsFile =
      properties.getProperty(
        "domino.setup.file",
        dataDirectory + "/setup.json"
      );
    certID = properties.getProperty("cert.id.file", dataDirectory + "/cert.id");
    hostServerIDFilePath =
      properties.getProperty(
        "host.server.id.file",
        dataDirectory + "/server.id"
      );
    // aclTemplate = properties.getProperty("acl.template.file", "default_cross_certify_acl.json");
    // successFileName = properties.getProperty("output.file", DEFAULT_SUCCESS_FILE);
    String debugStr = properties.getProperty("debug", "false");
    if (null != debugStr && debugStr.equalsIgnoreCase("true")) {
      debugMode = true;
    } else {
      debugMode = false;
    }
  }

  /**
   * Get the requested property from the Properties object.
   * If the value is null or empty, throw an exception
   * This is intended to be used for properties where defaulting the value would not make sense
   * @param properties   the properties object
   * @param key  the property key
   * @throws Exception if the property is missing
   */
  protected static String readRequiredProperty(
    Properties properties,
    String key
  ) throws Exception {
    String value = properties.getProperty(key);
    if (null == value || value.trim().isEmpty()) { // will I want to allow an empty value in some cases?
      throw new Exception("Missing value for property '" + key + "'.");
    }
    return value;
  }

  /**
   * Determine the server administrator by reading notes.ini
   * This requires that {@link #dataDirectory} is set.
   * @return  the raw name of the server admin for the local Domino installation
   * @throws Exception if the server administrator could not be looked up
   */
  protected static String getServerAdmin() throws Exception {
    String serverAdmin = null;
    BufferedReader reader = null;
    String iniPath = dataDirectory + File.separator + "notes.ini";

    // Admin=CN=Demo Admin/O=TEST1201
    Pattern adminPattern = Pattern.compile(
      "admin\\s*=\\s*(\\S.*)$",
      Pattern.CASE_INSENSITIVE
    );

    try {
      reader = new BufferedReader(new FileReader(iniPath));
      String line = reader.readLine();

      while (line != null) {
        Matcher matcher = adminPattern.matcher(line);
        if (matcher.matches()) {
          serverAdmin = matcher.group(1);
          serverAdmin = serverAdmin.trim();
          break;
        }
        // else:  continue searching

        // read next line
        line = reader.readLine();
      }

      reader.close();
    } finally {
      if (null != reader) {
        reader.close();
      }
    }

    if (null == serverAdmin || serverAdmin.trim().isEmpty()) {
      throw new Exception("Failed to lookup server admin.");
    }
    return serverAdmin;
  }

  protected static void log(String message) {
    System.out.println(message);
  }

  protected static void debug(String message) {
    final String debugPrefix = "	(debug)";
    if (debugMode) {
      log(debugPrefix + message);
    }
  }

  protected static void log(Throwable t) {
    t.printStackTrace(System.out);
  }
}
