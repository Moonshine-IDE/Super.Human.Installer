package superhuman.components.filesync;

import feathers.controls.Radio;
import feathers.core.ToggleGroup;
import superhuman.server.SyncMethod;
import genesis.application.theme.GenesisApplicationTheme;
import genesis.application.components.AdvancedAssetLoader;
import feathers.layout.HorizontalLayoutData;
import genesis.application.managers.LanguageManager;
import feathers.controls.LayoutGroup;
import openfl.events.Event;

@:build(mxhx.macros.MXHXComponent.build())
class FileSyncSetting extends LayoutGroup {

    final _width:Float = GenesisApplicationTheme.GRID * 100;

    var _radioGroupSyncMethod:ToggleGroup;

    public var selectedSyncMethod( get, set ):SyncMethod;
    var _selectedSyncMethod:SyncMethod;
    function get_selectedSyncMethod():SyncMethod return _selectedSyncMethod;
    function set_selectedSyncMethod( value:SyncMethod ):SyncMethod {
        _selectedSyncMethod = value;  
        
        _radioGroupSyncMethod.selectedIndex = value == SyncMethod.SCP ? 0 : 1;
        return _selectedSyncMethod;
    }

    public function new() 
    {
        super();

        _radioGroupSyncMethod = new ToggleGroup();
        _radioGroupSyncMethod.addEventListener(Event.CHANGE, _radioGroupChange);

        scpCheck.toggleGroup = _radioGroupSyncMethod;
        rsyncCheck.toggleGroup = _radioGroupSyncMethod;
    }

    function _radioGroupChange(event:Event) {
        var group = cast(event.currentTarget, ToggleGroup);
        var radio = cast(group.selectedItem, Radio);
        selectedSyncMethod = group.selectedIndex == 0 ? SyncMethod.SCP : SyncMethod.Rsync;
    }
}