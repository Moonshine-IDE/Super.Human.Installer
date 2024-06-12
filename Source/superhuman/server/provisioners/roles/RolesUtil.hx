package superhuman.server.provisioners.roles;

class RolesUtil  
{
	public static function getDominoRole(provisionerVersion:String, role:String, enabled:Bool = true):String
	{
		var rolePrefix:String = enabled ? "- name: " : "#- name: ";
		var dominoRole:String = "";
		
		if (provisionerVersion < "0.1.22")
		{
			dominoRole = rolePrefix + "domino_" + role;
		}
		else if (provisionerVersion == "0.1.22")
		{
			dominoRole = rolePrefix + "hcl_domino_" + role;
		}
		else 
		{
			dominoRole = rolePrefix + "startcloud.hcl_roles.domino_" + role;
		}
		
		return dominoRole;
	}
	
	public static function getOtherRole(provisionerVersion:String, role:String, enabled:Bool = true):String
	{
		var rolePrefix:String = enabled ? "- name: " : "#- name: ";
		var dominoRole:String = "";
		
		if (provisionerVersion <= "0.1.22")
		{
			dominoRole = rolePrefix + "startcloud_" + role;
		}
		else 
		{
			dominoRole = rolePrefix + "startcloud.startcloud_roles." + role;
		}
		
		return dominoRole;
	}
}