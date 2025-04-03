package net.prominic.domino.vagrant;

import java.io.BufferedReader;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileReader;
import java.util.Properties;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

import org.json.JSONObject;
import org.json.JSONTokener;

import lotus.domino.*;

/** 
 * Register and additional Domino server from the local server.
 * Expected to run on a hcl_domino_standalone_provisioner Vagrant instance.
 * @see https://help.hcltechsw.com/dom_designer/12.0.2/basic/H_EXAMPLE_REGISTERNEWSERVER_METHOD_JAVA.html
 */
public class CreateAdditionalServerID extends AgentBase {
 
	private static final String APP_NAME = "CreateAdditionalServerID";

	/** Reuse the generated properties file for CrossCertifyNotesID by default */
	protected static final String DEFAULT_PROPERTIES_FILE = "CrossCertifyNotesID.properties";
	protected static String dataDirectory = null;
	protected static String certID = null;
	protected static String settingsFile = null;
	// protected static String aclTemplate = null;
	protected static boolean debugMode = true;

 
	public static void main(String[] args) {
		Session session = null;
		DateTime dt = null;
		FileInputStream fis = null;
		try {
			System.out.println("Application '" + APP_NAME + "' started.");
			
			
			NotesThread.sinitThread();
			
			loadSharedProperties();

			// The JSON file used for Domino server setup can also be used for for this configuration
			fis = new FileInputStream(settingsFile);
			JSONObject json = (JSONObject)new JSONTokener(fis).nextValue();
			JSONObject serverSetup = json.getJSONObject("serverSetup");
			JSONObject serverConfig = serverSetup.getJSONObject("server");

			
			// Arguments:
			if (args.length < 1) {
				throw new Exception("No properties file specified for the additional server.");
			}
			String additionalServerPropertiesFileName = args[0];
			File additionalServerPropertiesFile = new File(additionalServerPropertiesFileName);
			if (!additionalServerPropertiesFile.exists()) {
				throw new Exception("Could not find file '" + additionalServerPropertiesFileName + "'.");
			}
			log("Loading additional server properties:  '" + additionalServerPropertiesFile.getAbsolutePath() + "'.");
			Properties additionalServerProperties = new Properties();
			try {
				fis = new FileInputStream(additionalServerPropertiesFile);
				additionalServerProperties.load(fis);
			}
			catch (Exception ex) {
				throw new Exception("Could not load properties file '" + additionalServerPropertiesFile.getAbsolutePath() + "'." );
			}
			finally {
				if (null != fis) {
					try {
						fis.close();
					}
					catch (Exception ex) {
						// ignore
					}
				}
			}
			
			// TODO:  load properties and verify they are non-empty.  Allow defaults as appropriate
			String additionalServerName = readRequiredProperty(additionalServerProperties, "server.name");
			String additionalServerPassword = additionalServerProperties.getProperty("server.id.password", null);
			if (null == additionalServerPassword || additionalServerPassword.isEmpty()) {
				// An empty string triggers this error:  Notes error: No password specified (test-additional-2.shi.com)
				// Use null instead to indicate no password
				// NOTE:  Adding a password to the server ID means that it will be required on server startup
				additionalServerPassword = null;
				System.out.println("Creating the new server.id with no password.");
			}
			String additionalServerTitle = readRequiredProperty(additionalServerProperties, "server.id.title");
			String outputIDFile = readRequiredProperty(additionalServerProperties, "server.id.output");
			
			// Read from server configuration:
			String domainName = serverConfig.getString("domainName");
			String serverAdministrator =  getServerAdmin();  // use local server admin 
			String registrationServer = serverConfig.getString("name");
			String certIDPassword = serverSetup.getJSONObject("org").getString("certifierPassword");  // not in original steps below
			
			// Create the session
			// currently we are using the admin user for actions like this
			String userPassword = serverSetup.getJSONObject("admin").getString("password");
			String sessionServer = null; // local server
			String sessionUser = null;  // default user
			debug("NotesFactory.createSession");
			session = NotesFactory.createSession(sessionServer, args, sessionUser, userPassword);
			log("Running on Notes Version: '" + session.getNotesVersion() + "'.");
			

			// (Your code goes here) 
			Registration reg = session.createRegistration();
			reg.setRegistrationServer(registrationServer);
			reg.setCreateMailDb(false);
			reg.setCertifierIDFile(certID);
			
			// expire in 1 year
			dt = session.createDateTime("Today");
			dt.setNow();
			dt.adjustYear(1);
			reg.setExpiration(dt);
			
			reg.setIDType(Registration.ID_HIERARCHICAL);
			// password strength.  0 means that the password is optional
			// https://help.hcl-software.com/dom_designer/12.0.0/basic/H_MINPASSWORDLENGTH_PROPERTY_JAVA.html
			//System.out.println("Original MinPasswordLength:  " + reg.getMinPasswordLength());
			reg.setMinPasswordLength(0); 
			System.out.println("Updated MinPasswordLength:  " + reg.getMinPasswordLength());
			reg.setNorthAmerican(true);
			//reg.setOrgUnit("AceHardwareNE");
			reg.setRegistrationLog("log.nsf");
			reg.setUpdateAddressBook(true);
			reg.setStoreIDInAddressBook(true);
			if (reg.registerNewServer(additionalServerName, // server name
				outputIDFile, // file to be created
				domainName, // domain name
				additionalServerPassword, // password for server ID
				certIDPassword, // certifier password
				"", // location field
				"", // comment field
				"", // Notes named network
				serverAdministrator, // server administrator
				additionalServerTitle)) // Domino Directory title field
			{ 
				System.out.println("Registration succeeded!  Server ID created at:  " + outputIDFile); 
			}
			else { 
				System.out.println("Registration failed"); 
			}

		}
		catch (Throwable throwable) {
			throwable.printStackTrace();
		}
		finally {
			try {
					if (null != dt) {  dt.recycle(); }
				if (null != session) {
					session.recycle();
				}
				if (null != fis) { fis.close(); }
			}
			catch (Exception ex) {
				ex.printStackTrace();
			}
			NotesThread.stermThread();
			System.out.println("Application '" + APP_NAME + "' completed.");
		}
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
		debug ("propertiesFileName='" + propertiesFileName + "'.");
		if (null == propertiesFileName || propertiesFileName.isEmpty()) {
			propertiesFileName = DEFAULT_PROPERTIES_FILE;
		}

		Properties properties = new Properties();
		File propertiesFile = new File(propertiesFileName);
		if (propertiesFile.exists()) {
			log("Loading properties file '" + propertiesFile.getAbsolutePath() + "'.");
			FileInputStream fis = null;
			try {
				fis = new FileInputStream(propertiesFile);
				properties.load(fis);
			}
			catch (Exception ex) {
				log("Could not load properties file '" + propertiesFile.getAbsolutePath() + "'.  Using defaults..." );
			}
			finally {
				if (null != fis) {
					try {
						fis.close();
					}
					catch (Exception ex) {
						// ignore
					}
				}
			}
		}
		else {
			log("Properties file '" + propertiesFile.getAbsolutePath() + "' does not exist.  Using defaults...");
		}

		// read the properties
		dataDirectory = properties.getProperty("data.directory", "/local/notesdata");
		settingsFile = properties.getProperty("domino.setup.file", dataDirectory + "/setup.json");
		certID = properties.getProperty("cert.id.file", dataDirectory + "/cert.id");
		// aclTemplate = properties.getProperty("acl.template.file", "default_cross_certify_acl.json");
		// successFileName = properties.getProperty("output.file", DEFAULT_SUCCESS_FILE);
		String debugStr = properties.getProperty("debug", "false");
		if (null != debugStr && debugStr.equalsIgnoreCase("true")) {
			debugMode = true;
		}
		else {
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
	protected static String readRequiredProperty(Properties properties, String key) throws Exception {
		String value = properties.getProperty(key);
		if (null == value || value.trim().isEmpty()) {  // will I want to allow an empty value in some cases?
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
		Pattern adminPattern = Pattern.compile("admin\\s*=\\s*(\\S.*)$", Pattern.CASE_INSENSITIVE);

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
		} 
		finally {
			if (null != reader) { reader.close(); }
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
