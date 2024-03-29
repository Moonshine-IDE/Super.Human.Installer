/*
 *  Copyright (C) 2016-present Prominic.NET, Inc.
 *
 *  This program is free software: you can redistribute it and/or modify
 *  it under the terms of the Server Side Public License, version 1,
 *  as published by MongoDB, Inc.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 *  Server Side Public License for more details.
 *
 *  You should have received a copy of the Server Side Public License
 *  along with this program. If not, see
 *
 *  http://www.mongodb.com/licensing/server-side-public-license
 *
 *  As a special exception, the copyright holders give permission to link the
 *  code of portions of this program with the OpenSSL library under certain
 *  conditions as described in each individual source file and distribute
 *  linked combinations including the program with the OpenSSL library. You
 *  must comply with the Server Side Public License in all respects for
 *  all of the code used other than as permitted herein. If you modify file(s)
 *  with this exception, you may extend this exception to your version of the
 *  file(s), but you are not obligated to do so. If you do not wish to do so,
 *  delete this exception statement from your version. If you delete this
 *  exception statement from all source files in the program, then also delete
 *  it in the license file.
 */

package genesis.application;

import superhuman.browser.Browsers;
import champaign.core.logging.Logger;
import champaign.core.primitives.VersionInfo;
import champaign.sys.logging.targets.FileTarget;
import champaign.sys.logging.targets.SysPrintTarget;
import feathers.controls.Application;
import feathers.controls.LayoutGroup;
import feathers.controls.navigators.PageItem;
import feathers.data.ArrayCollection;
import feathers.layout.AnchorLayout;
import feathers.layout.AnchorLayoutData;
import feathers.layout.VerticalAlign;
import feathers.layout.VerticalLayout;
import feathers.layout.VerticalLayoutData;
import feathers.style.Theme;
import genesis.application.components.AboutPage;
import genesis.application.components.Footer;
import genesis.application.components.GenesisNavigator;
import genesis.application.components.Header;
import genesis.application.components.LoginControl;
import genesis.application.components.LoginPage;
import genesis.application.components.Page;
import genesis.application.components.SupportPage;
import genesis.application.components.UpdatePage;
import genesis.application.events.GenesisApplicationEvent;
import genesis.application.managers.LanguageManager;
import genesis.application.managers.ToastManager;
import genesis.application.theme.GenesisApplicationTheme;
import genesis.application.updater.GenesisApplicationUpdater;
import genesis.application.updater.GenesisApplicationUpdaterEvent;
import genesis.remote.GenesisRemote;
import genesis.remote.events.AuthEvent;
import haxe.Exception;
import lime.system.System;
import lime.ui.Window;
import openfl.Lib;
import openfl.events.Event;
import openfl.system.Capabilities;
import prominic.sys.applications.bin.Shell;
import prominic.sys.tools.SysTools;
import sys.FileSystem;
import sys.io.File;

#if buildmacros
@:build( BuildMacro.createGitInfo() )
#end

abstract class GenesisApplication extends Application {

    static public final GENESIS_ADDRESS:String = "https://genesis.directory/";
    static public final LANGUAGE_FILE:String = "assets/text/en_US.json";
    static public final PAGE_ABOUT:String = "page-about";
    static public final PAGE_LOGIN:String = "page-login";
    static public final PAGE_SUPPORT:String = "page-support";
    static public final PAGE_UPDATE:String = "page-update";

    static var _instance:GenesisApplication;

    static public function getInstance():GenesisApplication {

        return _instance;

    }

    var _aboutPage:AboutPage;
    var _canExit:Bool;
    var _company:String;
    var _content:LayoutGroup;
    var _cpuArchitecture:CPUArchitecture;
    var _crashLogTarget:FileTarget;
    var _footer:Footer;
    var _hasLogin:Bool;
    var _header:Header;
    var _internalPages:Map<String, PageItem>;
    var _layout:VerticalLayout;
    var _loginControl:LoginControl;
    var _loginPage:LoginPage;
    var _navigator:GenesisNavigator;
    var _pages:ArrayCollection<PageItem>;
    var _previousNavigatorIndex:Int;
    var _previousPageId:String;
    var _remote:GenesisRemote;
    var _selectedPageId:String;
    var _showLoginPage:Bool = false;
    var _supportPage:SupportPage;
    var _title:String;
    var _toastGroup:LayoutGroup;
    var _updatePage:UpdatePage;
    var _updater:GenesisApplicationUpdater;
    var _updaterAddress:String;
    var _version:String;
    var _versionInfo:VersionInfo;
    var _window:Window;
    var _startFilePath:String;
    var _crashLogFilePath:String;

    var _appConfigUseColoredOutput:Bool = false;
    var _appConfigUseTimestamps:Bool = true;
    var _appConfigUseMachineReadable:Bool = false;
    var _appConfigDefaultLogLevel:LogLevel = LogLevel.Info;

    public var company( get, never ):String;
    function get_company() return _company;

    public var cpuArchitecture( get, never ):CPUArchitecture;
    function get_cpuArchitecture() return _cpuArchitecture;

    public var previousPageId( get, never ):String;
    function get_previousPageId() return _previousPageId;

    public var title( get, never ):String;
    function get_title() return _title;

    public var selectedPageId( get, set ):String;
    function get_selectedPageId() return _selectedPageId;
    function set_selectedPageId( value:String ) {
        if ( value == _selectedPageId ) return value;
        if ( _internalPages.exists( value ) ) {
            _previousPageId = _selectedPageId;
            _navigator.selectedItem = _internalPages.get( value );
            _selectedPageId = value;
            _pageChanged();
        }
        return _selectedPageId;
    }

    public var updater( get, never ):GenesisApplicationUpdater;
    function get_updater() return _updater;

    public function new( hasLogin:Bool = false, showLoginPage:Bool = false ) {

        super();

        _instance = this;

        _window = lime.app.Application.current.window;

        _processArgs();
        
        #if final
            #if debug
            _appConfigDefaultLogLevel = LogLevel.Debug;
            #else
            _appConfigDefaultLogLevel = LogLevel.Info;
            #end
            _appConfigUseMachineReadable = false;
        #else
            #if debug
                _appConfigDefaultLogLevel = #if logverbose LogLevel.Verbose #else LogLevel.Debug #end;
            #end
            #if logcolor _appConfigUseColoredOutput = true; #end
            #if logmr _appConfigUseMachineReadable = true; #end
        #end

        Logger.init( _appConfigDefaultLogLevel, true );
        Logger.addTarget( new SysPrintTarget( _appConfigDefaultLogLevel, _appConfigUseTimestamps, _appConfigUseMachineReadable, _appConfigUseColoredOutput ) );
        var ft = new FileTarget( System.applicationStorageDirectory + "logs", "current.txt", 9, _appConfigDefaultLogLevel, _appConfigUseTimestamps, _appConfigUseMachineReadable );
        Logger.addTarget( ft );

        // Crash related features
        _startFilePath = System.applicationStorageDirectory + "start";
        _crashLogFilePath = System.applicationStorageDirectory + "logs/crash.txt";

        _hasLogin = hasLogin;
        _showLoginPage = hasLogin && showLoginPage;
        _company = "Prominic.NET";
        _title = Lib.application.meta.get( "name" );
        _version = Lib.application.meta.get( "version" );
        _versionInfo = _version;

        if ( FileSystem.exists( ft.currentLogFilePath ) ) 
            Logger.info( '${this}: Log file created at ${ft.currentLogFilePath}' )
        else
            Logger.warning( '${this}: Log file creation failed at ${ft.currentLogFilePath}' );

        Logger.info( '${this}: Initializing ${_title} v${_version}...' );

        _cpuArchitecture = prominic.sys.tools.SysTools.getCPUArchitecture();

        #if cpp
        Logger.info( '${this}: Platform: Native(C++), OS: ${Capabilities.os} (${Capabilities.version}), CPU: ${_cpuArchitecture}' );
        #elseif neko
        Logger.info( '${this}: Platform: Neko, OS: ${Capabilities.os} (${Capabilities.version}), CPU: ${_cpuArchitecture}' );
        #else
        Logger.info( '${this}: Platform: Unknown, OS: ${Capabilities.os} (${Capabilities.version}), CPU: ${_cpuArchitecture}' );
        #end
		Logger.info( '${this}: SysInfo: DevideModel: ${System.deviceModel} DeviceVendor: ${System.deviceVendor} Endianness: ${System.endianness} PlatformLabel: ${System.platformLabel} PlatformName: ${System.platformName} PlatformVersion: ${System.platformVersion}' );
        Logger.info( #if debug '${this}: Debug build: true' #else '${this}: Debug build: false' #end );
        Logger.debug( '${this}: Application storage directory: ${System.applicationStorageDirectory}' );

        ApplicationMain.onException.add( _onHaxeException );

        this.disabledAlpha = .5;

        LanguageManager.getInstance().load( LANGUAGE_FILE );

        _internalPages = [];

        _updater = new GenesisApplicationUpdater();

    }

    function _processArgs() {

        var args = Sys.args();

        for( arg in args ) {

            if ( arg == "--color" ) _appConfigUseColoredOutput = true;
            if ( arg == "--notimestamp" ) _appConfigUseTimestamps = false;
            if ( arg == "--mr" ) _appConfigUseMachineReadable = true;

            if ( arg.indexOf( "--loglevel=") > -1 ) {

                var level = arg.split( "--loglevel=" )[ 1 ];

                if ( level != null || level != "" ) {

                    switch ( level ) {

                        case "none" | "0":
                            _appConfigDefaultLogLevel = LogLevel.None;

                        case "fatal" | "1":
                            _appConfigDefaultLogLevel = LogLevel.Fatal;

                        case "error" | "2":
                            _appConfigDefaultLogLevel = LogLevel.Error;

                        case "warning" | "3":
                            _appConfigDefaultLogLevel = LogLevel.Warning;

                        #if debug
                        case "debug" | "4":
                            _appConfigDefaultLogLevel = LogLevel.Debug;

                        case "verbose" | "5":
                            _appConfigDefaultLogLevel = LogLevel.Verbose;
                        #end

                        default:
                            _appConfigDefaultLogLevel = LogLevel.Info;

                    }

                }

            }

        }

    }

    override function initialize() {

        super.initialize();

        _window.title = '${_title} v${_version}';
        _title = StringTools.replace( _title, " Development", "" );
        _window.onFocusIn.add( _onWindowFocusIn );
        _window.onFocusOut.add( _onWindowFocusOut );
        _window.onResize.add( _onWindowResize );
        _window.onClose.add( _onWindowClose );
        lime.app.Application.current.onExit.add( _onExit );

        _remote = new GenesisRemote();
        _remote.addEventListener( AuthEvent.COMPLETE, _authComplete );
        
        Theme.setTheme( new GenesisApplicationTheme( #if lighttheme ThemeMode.Light #end ) );

        this.layout = new AnchorLayout();

        _content = new LayoutGroup();
        _content.variant = GenesisApplicationTheme.APPLICATION;
        _content.layoutData = AnchorLayoutData.fill();
        this.addChild( _content );

        _layout = new VerticalLayout();
        _layout.verticalAlign = VerticalAlign.TOP;
        _content.layout = _layout;

        _header = new Header();
        _header.text = '${_title}';
        _header.layoutData = new VerticalLayoutData( 100 );
        _header.addEventListener( GenesisApplicationEvent.INIT_UPDATE, _initUpdate );
        _header.addEventListener( GenesisApplicationEvent.MENU_SELECTED, _menuSelected );
        _header.addMenuItem( LanguageManager.getInstance().getString( 'mainmenu.about' ), PAGE_ABOUT );
        _header.addMenuItem( LanguageManager.getInstance().getString( 'mainmenu.support' ), PAGE_SUPPORT );
        _header.menuEnabled = false;
        _content.addChild( _header );

        _pages = new ArrayCollection<PageItem>();

        _navigator = new GenesisNavigator();
        _navigator.dataProvider = _pages;
        _navigator.layoutData = new VerticalLayoutData( 100, 100 );
        _navigator.swipeEnabled = false;
        _navigator.simulateTouch = false;
        _content.addChild( _navigator );

        _footer = new Footer();
        _footer.appInfo = LanguageManager.getInstance().getString( 'footer.copyright', _company, Std.string( Date.now().getFullYear() ) );
        var build:String = #if neko "Neko" #elseif cpp "Native" #else "Unsupported" #end;
        var isDebug:String = #if debug "Debug | " #else "" #end;
        _footer.sysInfo = '${build} | ${isDebug}${Capabilities.os} | ${_cpuArchitecture}';
        _footer.layoutData = new VerticalLayoutData( 100 );
        _content.addChild( _footer );

        _loginControl = new LoginControl( !_showLoginPage );
        _loginControl.addEventListener( GenesisApplicationEvent.LOGIN, _startLogin );
        _loginControl.visible = _hasLogin;
        //this._header.addChild( _loginControl );

        _loginPage = new LoginPage();
        _loginPage.addEventListener( GenesisApplicationEvent.LOGIN, _loginSubmitted );
        _loginPage.addEventListener( GenesisApplicationEvent.CANCEL, _loginCancelled );
        //addPage( _loginPage, PAGE_LOGIN );

        _aboutPage = new AboutPage();
        _aboutPage.addEventListener( GenesisApplicationEvent.VISIT_GENESIS_DIRECTORY, _visitGenesisDirectory );
        _aboutPage.addEventListener( GenesisApplicationEvent.VISIT_SOURCE_CODE, _visitSourceCode );
        addPage( _aboutPage, PAGE_ABOUT );

        _supportPage = new SupportPage();
        _supportPage.addEventListener( GenesisApplicationEvent.OPEN_LOGS_DIRECTORY, _openLogsDirectory );
        _supportPage.addEventListener( GenesisApplicationEvent.VISIT_SOURCE_CODE_ISSUES, _visitSourceCodeIssues );
        addPage( _supportPage, PAGE_SUPPORT );

        _updatePage = new UpdatePage();
        _updatePage.addEventListener( GenesisApplicationEvent.CANCEL_UPDATE_PAGE, _cancelUpdatePage );
        addPage( _updatePage, PAGE_UPDATE );

        _toastGroup = new LayoutGroup();
        _toastGroup.variant = GenesisApplicationTheme.LAYOUT_GROUP_TOAST_CONTAINER;
        _toastGroup.mouseChildren = _toastGroup.mouseEnabled = false;
        this.addChild( _toastGroup );
        
        ToastManager.getInstance().container = _toastGroup;

        #if !neko
        _updater.addEventListener( GenesisApplicationUpdaterEvent.UPDATE_FOUND, _updateFound );
        _updater.addEventListener( GenesisApplicationUpdaterEvent.EXIT_APP, _exitApp );
        _updater.addEventListener( GenesisApplicationUpdaterEvent.DOWNLOAD_START, _downloadStart );
        _updater.addEventListener( GenesisApplicationUpdaterEvent.DOWNLOAD_CANCELLED, _downloadCancelled );
        _updater.addEventListener( GenesisApplicationUpdaterEvent.DOWNLOAD_FAILED, _downloadCancelled );
        if ( _updaterAddress != null ) _updater.checkUpdates( _updaterAddress );
        #end

        if ( _startFileExists() ) {
            
            _showCrashAlert();

        } else {

            _createCrashLog();

        }

        _createStartFile();

    }

    function _updateFound( e:Event ) {

        Logger.debug( '${this}: Update found: ${ _updater.updaterInfoEntry }' );
        _header.updateFound();
        
    }

    function _exitApp( e:GenesisApplicationUpdaterEvent ) {

        openfl.system.System.exit( 0 );

    }

    function _downloadStart( e:GenesisApplicationUpdaterEvent ) {

        _header.menuEnabled = false;

    }

    function _downloadCancelled( e:GenesisApplicationUpdaterEvent ) {

        _header.menuEnabled = true;

    }

    function _initUpdate( e:GenesisApplicationEvent ) {

        this.selectedPageId = PAGE_UPDATE;

    }

    public function addPage( page:Page, ?index:Int, ?id:String ) {

        var pi = PageItem.withDisplayObject( page );
        if ( id != null ) _internalPages.set( id, pi );
        _navigator.dataProvider.addAt( pi, ( index != null ) ? index : _navigator.dataProvider.length );

    }

    public function removePageById( id:String ) {

        if ( _internalPages.exists( id ) ) {

            var pi = _internalPages.get( id );
            _navigator.dataProvider.remove( pi );
            _internalPages.remove( id );

            if ( _previousPageId == id ) _previousPageId = null;

            for ( kv in _internalPages.keyValueIterator() ) {

                if ( kv.value == _navigator.selectedItem ) _selectedPageId = kv.key;

            }

        }

    }

    public override function toString():String {

        return '[GenesisApplication]';

    }

    function _loginCancelled( e:GenesisApplicationEvent ) {

        _loginControl.visible = true;
        _navigator.selectedIndex = _previousNavigatorIndex;

    }

    function _authComplete( e:AuthEvent ) {
        
        if ( e.success ) {

            _loginSuccess();

        } else {



        }

    }

    function _loginSubmitted( e:GenesisApplicationEvent ) {

        _remote.authenticate( e.username, e.password, true );

    }

    function _loginSuccess() {

        _loginControl.loggedIn = true;
        _loginControl.username = _remote.user.username;
        _loginControl.visible = true;

        ToastManager.getInstance().showToast( "Successfully signed in", false );

        this._navigator.selectedIndex = _previousNavigatorIndex;

    }

    function _onExit( exitCode:Int ) {

        _deleteStartFile();

    }

    function _onWindowClose() {}

    function _onWindowFocusIn() {}

    function _onWindowFocusOut() {}

    function _onWindowResize( w:Int, h:Int ) {}

    function _startLogin( e:GenesisApplicationEvent ) {

        _previousNavigatorIndex = _navigator.selectedIndex;
        _navigator.selectedIndex = _navigator.dataProvider.length - 1;
        _loginControl.visible = false;

    }

    function _visitGenesisDirectory( ?e:Dynamic ) {
		Browsers.openLink(GENESIS_ADDRESS);
    }

    function _visitSourceCode( ?e:Dynamic ) {}

    function _visitSourceCodeIssues( ?e:Dynamic ) {}

    function _visitSourceCodeNewIssue( ?e:Dynamic ) {}

    function _menuSelected( e:GenesisApplicationEvent ) {

        this.selectedPageId = e.pageId;

    }

    function _openLogsDirectory( ?e:Dynamic ) {

        Shell.getInstance().open( [ System.applicationStorageDirectory + "logs" ] );

    }

    function _cancelUpdatePage( e:GenesisApplicationEvent ) {

        if ( _previousPageId != null ) selectedPageId = _previousPageId;

    }

    function _pageChanged() { }

    function _onHaxeException( e:Dynamic ):Void {

        _createCrashLog();

        if ( Std.isOfType( e, Exception ) ) {

            Logger.fatal( 'Fatal exception : ${e}\nDetails : ${e.details()}\nNative : ${e.native}\nStack : ${e.stack}' );
            
        } else {

            Logger.fatal( 'Fatal error: ${e}' );
            
        }

    }

    function _createStartFile() {

        try {
            File.saveContent( _startFilePath, Date.now().toString() );
        } catch ( e ) {}

    }

    function _deleteStartFile() {

        try {

            FileSystem.deleteFile( _startFilePath );

        } catch ( e ) {}

    }

    function _startFileExists() {

        return FileSystem.exists( _startFilePath ) && !FileSystem.isDirectory( _startFilePath );

    }

    function _showCrashAlert() {}

    function _createCrashLog() {
        
        if ( _crashLogTarget == null ) {

            _crashLogTarget = new FileTarget( System.applicationStorageDirectory + "logs", "crash.txt", 0, LogLevel.Fatal, true, false, true );
            Logger.addTarget( _crashLogTarget );

        }

    }

    function _openCrashLog() {

        Shell.getInstance().open( [ _crashLogFilePath ] );

    }

}