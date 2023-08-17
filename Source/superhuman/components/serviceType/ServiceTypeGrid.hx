package superhuman.components.serviceType;

import feathers.layout.HorizontalLayoutData;
import feathers.layout.HorizontalLayout;
import feathers.data.GridViewCellState;
import feathers.data.GridViewHeaderState;
import feathers.layout.AnchorLayoutData;
import feathers.utils.DisplayObjectRecycler;
import superhuman.server.data.ServiceTypeData;
import feathers.data.IFlatCollection;
import genesis.application.theme.GenesisApplicationTheme;
import feathers.controls.Label;
import feathers.controls.dataRenderers.LayoutGroupItemRenderer;
import feathers.controls.GridView;
import superhuman.theme.SuperHumanInstallerTheme;

class ServiceTypeGrid extends GridView 
{
	public function new(?dataProvider:IFlatCollection<ServiceTypeData>)
	{
		super(dataProvider);
		
		this.variant = GridView.VARIANT_BORDERLESS;
		this.layoutData = AnchorLayoutData.fill();
		
	 	this.headerRendererRecycler = DisplayObjectRecycler.withFunction(() -> {
            return (new GridViewHeader());
		}, (itemRenderer:GridViewHeader, state:GridViewHeaderState) -> {
			itemRenderer.label.text = state.text;
		},
		(itemRenderer:GridViewHeader, state:GridViewHeaderState) -> {
			itemRenderer.label.text = "";
		});
		
        	this.cellRendererRecycler = DisplayObjectRecycler.withFunction(() -> {
            return (new GridViewColumnMultiline());
		}, (itemRenderer:GridViewColumnMultiline, state:GridViewCellState) -> {
			itemRenderer.label.text = state.text;
		},
		(itemRenderer:GridViewColumnMultiline, state:GridViewCellState) -> {
			itemRenderer.label.text = "";
		});
	}
}

@:styleContext
class GridViewHeader extends LayoutGroupItemRenderer 
{
	private var _label:Label;
	public var label(get, never):Label;
	private function get_label():Label 
    {
		return this._label;
	}

	override private function initialize():Void 
	{
		this.variant = SuperHumanInstallerTheme.GRID_VIEW_HEADER_VARIANT;
		
        var layout = new HorizontalLayout();
        layout.gap = 6.0;
        layout.paddingTop = 2.0;
        layout.paddingBottom = 4.0;
        layout.paddingLeft = 8.0;
        layout.paddingRight = 8.0;
        layout.verticalAlign = MIDDLE;
        this.layout = layout;

		this._label = new Label();
		this._label.variant = GenesisApplicationTheme.LABEL_TITLE;
        this._label.wordWrap = true;
        this._label.layoutData = new HorizontalLayoutData(100, null);
        this.addChild(_label);

		super.initialize();
	}
}

@:styleContext
class GridViewColumnMultiline extends LayoutGroupItemRenderer 
{
	private var _label:Label;
	public var label(get, never):Label;
	private function get_label():Label 
    {
		return this._label;
	}

	override private function initialize():Void 
	{
		this.variant = SuperHumanInstallerTheme.GRID_VIEW_COLUMN_VARIANT;

        var layout = new HorizontalLayout();
        layout.gap = 6.0;
        layout.paddingTop = 2.0;
        layout.paddingBottom = 4.0;
        layout.paddingLeft = 8.0;
        layout.paddingRight = 8.0;
        layout.verticalAlign = MIDDLE;
        this.layout = layout;

		this._label = new Label();
		this._label.variant = GenesisApplicationTheme.LABEL_DEFAULT;
        this._label.wordWrap = true;
        this._label.layoutData = new HorizontalLayoutData(100, null);
        this.addChild(_label);

		super.initialize();
	}
}