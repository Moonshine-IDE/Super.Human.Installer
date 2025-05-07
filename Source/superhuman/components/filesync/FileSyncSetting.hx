package superhuman.components.filesync;

import genesis.application.components.GenesisFormCheckBox;
import superhuman.server.SyncMethod;
import superhuman.config.SuperHumanGlobals;
import genesis.application.theme.GenesisApplicationTheme;
import feathers.controls.Label;
import feathers.layout.HorizontalLayoutData;
import genesis.application.managers.LanguageManager;
import feathers.controls.LayoutGroup;
import openfl.events.Event;

@:build(mxhx.macros.MXHXComponent.build())
class FileSyncSetting extends LayoutGroup {

    final _width:Float = GenesisApplicationTheme.GRID * 100;

    // UI components
    public var toggleContainer:LayoutGroup;
    private var _syncToggle:GenesisFormCheckBox;
    private var _scpLabel:Label;
    private var _rsyncLabel:Label;

    // Track if sync method should be disabled
    private var _isSyncDisabled:Bool = false;
    
    public var selectedSyncMethod(get, set):SyncMethod;
    var _selectedSyncMethod:SyncMethod;
    
    function get_selectedSyncMethod():SyncMethod return _selectedSyncMethod;
    function set_selectedSyncMethod(value:SyncMethod):SyncMethod {
        _selectedSyncMethod = value;
        
        // Update toggle based on selected method
        // true = rsync, false = scp
        if (_syncToggle != null) {
            _syncToggle.selected = (value == SyncMethod.Rsync);
        }
        
        return _selectedSyncMethod;
    }
    
    // Property to disable the toggle
    public var syncDisabled(get, set):Bool;
    
    function get_syncDisabled():Bool return _isSyncDisabled;
    function set_syncDisabled(value:Bool):Bool {
        _isSyncDisabled = value;
        
        // If disabled, make sure toggle is disabled but still visible
        if (_syncToggle != null) {
            _syncToggle.enabled = !value;
            
            // If we're disabling and rsync is selected, force switch to SCP
            if (value && _selectedSyncMethod == SyncMethod.Rsync) {
                selectedSyncMethod = SyncMethod.SCP;
            }
        }
        
        return _isSyncDisabled;
    }

    public function new() 
    {
        super();
        
        // Initialize in initialize callback to ensure component is built
        this.initializeNow();
    }
    
    override function initialize() {
        super.initialize();
        
        // Create SCP label (left side)
        _scpLabel = new Label();
        _scpLabel.text = "scp";
        _scpLabel.variant = genesis.application.theme.GenesisApplicationTheme.LABEL_DEFAULT;
        
        // Create the toggle checkbox with empty text (we'll use the side labels instead)
        _syncToggle = new GenesisFormCheckBox("", true);
        
        // Create rsync label (right side)
        _rsyncLabel = new Label();
        _rsyncLabel.text = "rsync";
        _rsyncLabel.variant = genesis.application.theme.GenesisApplicationTheme.LABEL_DEFAULT;
        
        // Add them to the container in order: scp label, toggle, rsync label
        toggleContainer.addChild(_scpLabel);
        toggleContainer.addChild(_syncToggle);
        toggleContainer.addChild(_rsyncLabel);
        
        // Set default selection
        _selectedSyncMethod = SyncMethod.Rsync;
        
        // Add event listener to toggle
        _syncToggle.addEventListener(Event.CHANGE, _toggleChanged);
    }
    
    private function _toggleChanged(event:Event):Void {
        // Update selected sync method based on toggle state
        // true = rsync, false = scp
        selectedSyncMethod = _syncToggle.selected ? SyncMethod.Rsync : SyncMethod.SCP;
    }
}
