package superhuman.server.hostsFileGenerator;

import superhuman.server.provisioners.AbstractProvisioner;

abstract class AbstractHostsFileGenerator {
    static public function generateContent( sourceTemplate:String, provisioner:AbstractProvisioner ):String {
        return null;
    }
}