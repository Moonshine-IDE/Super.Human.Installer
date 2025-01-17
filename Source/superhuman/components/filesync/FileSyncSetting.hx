package superhuman.components.filesync;

import superhuman.server.SyncMethod;
import superhuman.events.SuperHumanApplicationEvent;
import genesis.application.theme.GenesisApplicationTheme;
import genesis.application.components.AdvancedAssetLoader;
import feathers.layout.HorizontalLayoutData;
import genesis.application.managers.LanguageManager;
import feathers.controls.LayoutGroup;
import openfl.events.Event;

@:build(mxhx.macros.MXHXComponent.build())
class FileSyncSetting extends LayoutGroup {

    /*public function new() 
    {
        super();

        scpCheck.addEventListener(Event.CHANGE, _scpCheckChanged);
        rsyncCheck.addEventListener(Event.CHANGE, _rsyncCheckChanged);
        buttonWarningSync.icon = new AdvancedAssetLoader( GenesisApplicationTheme.getAssetPath( GenesisApplicationTheme.ICON_WARNING ) );
        labelWarningSync.text = LanguageManager.getInstance().getString( 'serverconfigpage.form.syncmethod.warning' );
    }

    function _scpCheckChanged(event:Event) {
        var scpCheckEvent = new SuperHumanApplicationEvent(SuperHumanApplicationEvent.SYNC_METHOD_CHANGE);
        scpCheckEvent.syncMethod = SyncMethod.SCP;
        this.dispatchEvent(scpCheckEvent);
    }

    function _rsyncCheckChanged(event:Event) {
        var rsyncCheckEvent = new SuperHumanApplicationEvent(SuperHumanApplicationEvent.SYNC_METHOD_CHANGE);
        rsyncCheckEvent.syncMethod = SyncMethod.Rsync;
        this.dispatchEvent(rsyncCheckEvent);
    }*/
}