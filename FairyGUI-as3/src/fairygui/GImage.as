package fairygui
{
	import flash.display.Bitmap;
	import flash.display.BitmapData;
	import flash.geom.ColorTransform;
	import flash.geom.Matrix;
	import flash.geom.Rectangle;
	
	import fairygui.display.UIImage;
	import fairygui.utils.ToolSet;

	public class GImage extends GObject implements IColorGear
	{
		private var _content:Bitmap;
		private var _bmdAfterFlip:BitmapData;
		private var _color:uint;
		private var _flip:int;
			
		public function GImage()
		{
			_color = 0xFFFFFF;
		}
		
		public function get color():uint
		{
			return _color;
		}
		
		public function set color(value:uint):void 
		{
			if(_color != value)
			{
				_color = value;
				updateGear(4);
				applyColor();
			}
		}
		
		private function applyColor():void
		{
			var ct:ColorTransform = _content.transform.colorTransform;
			ct.redMultiplier = ((_color>>16)&0xFF)/255;
			ct.greenMultiplier =  ((_color>>8)&0xFF)/255;
			ct.blueMultiplier = (_color&0xFF)/255;
			_content.transform.colorTransform = ct;
		}
		
		public function get flip():int
		{
			return _flip;
		}
		
		public function set flip(value:int):void
		{
			if(_flip!=value)
			{
				_flip = value;
				applyFlip();
			}
		}
		
		private function applyFlip():void
		{
			var source:BitmapData = packageItem.image;
			if(source==null)
				return;
			
			if(_flip!=FlipType.None)
			{
				var mat:Matrix = new Matrix();
				var a:int=1,b:int=1;
				if(_flip==FlipType.Both)
				{
					mat.scale(-1,-1);
					mat.translate(source.width, source.height);
				}
				else if(_flip==FlipType.Horizontal)
				{
					mat.scale(-1, 1);
					mat.translate(source.width, 0);
				}
				else
				{
					mat.scale(1,-1);
					mat.translate(0, source.height);
				}
				var tmp:BitmapData = new BitmapData(source.width,source.height,source.transparent,0);
				tmp.draw(source, mat);
				if(_content.bitmapData!=null && _content.bitmapData!=source)
					_content.bitmapData.dispose();
				_bmdAfterFlip = tmp;
			}
			else
			{
				if(_content.bitmapData!=null && _content.bitmapData!=source)
					_content.bitmapData.dispose();
				_bmdAfterFlip = source;
			}
			
			updateBitmap();
		}
		
		override protected function createDisplayObject():void
		{ 
			_content = new UIImage(this);
			setDisplayObject(_content);
		}
		
		override public function dispose():void
		{
			if(!packageItem.loaded)
				packageItem.owner.removeItemCallback(packageItem, __imageLoaded);
			
			if(_content.bitmapData!=null && _content.bitmapData!=_bmdAfterFlip && _content.bitmapData!=packageItem.image)
			{
				_content.bitmapData.dispose();
				_content.bitmapData = null;
			}
			if(_bmdAfterFlip!=null && _bmdAfterFlip!=packageItem.image)
			{
				_bmdAfterFlip.dispose();
				_bmdAfterFlip = null;
			}
			
			super.dispose();
		}
		
		override public function constructFromResource():void
		{
			_sourceWidth = packageItem.width;
			_sourceHeight = packageItem.height;
			_initWidth = _sourceWidth;
			_initHeight = _sourceHeight;
			
			setSize(_sourceWidth, _sourceHeight);
			
			if(packageItem.loaded)
				__imageLoaded(packageItem);
			else
				packageItem.owner.addItemCallback(packageItem, __imageLoaded);
		}

		private function __imageLoaded(pi:PackageItem):void
		{
			_content.bitmapData = pi.image;
			_content.smoothing = packageItem.smoothing;
			applyFlip();
		}
		
		override protected function handleSizeChanged():void
		{
			if(packageItem.scale9Grid==null && !packageItem.scaleByTile)
				_sizeImplType = 1;
			else
				_sizeImplType = 0;
			handleScaleChanged();
			updateBitmap();
		}
		
		private function updateBitmap():void
		{
			if(_bmdAfterFlip==null)
				return;
			
			var oldBmd:BitmapData = _content.bitmapData;
			var newBmd:BitmapData;
			
			if(packageItem.scale9Grid!=null)
			{
				var w:Number = this.width;
				var h:Number = this.height;
				
				if(_bmdAfterFlip.width==w && _bmdAfterFlip.height==h)
					newBmd = _bmdAfterFlip;
				else if(w<=0 || h<=0)
					newBmd = null;
				else
				{
					var rect:Rectangle;
					if(_flip!=FlipType.None)
					{
						rect = packageItem.scale9Grid.clone();
						if(_flip==FlipType.Horizontal || _flip==FlipType.Both)
						{
							rect.x = _bmdAfterFlip.width - rect.right;
							rect.right = rect.x + rect.width;
						}
						
						if(_flip==FlipType.Vertical || _flip==FlipType.Both)
						{
							rect.y = _bmdAfterFlip.height - rect.bottom;
							rect.bottom = rect.y + rect.height;
						}
					}
					else
						rect = packageItem.scale9Grid;
					
					newBmd = ToolSet.scaleBitmapWith9Grid(_bmdAfterFlip, 
						rect, w, h, packageItem.smoothing, packageItem.tileGridIndice);
				}
			}
			else if(packageItem.scaleByTile)
			{
				w = this.width;
				h = this.height;
				oldBmd = _content.bitmapData;
				
				if(_bmdAfterFlip.width==w && _bmdAfterFlip.height==h)
					newBmd = _bmdAfterFlip;
				else if(w==0 || h==0)
					newBmd = null;
				else
					newBmd =  ToolSet.tileBitmap(_bmdAfterFlip, _bmdAfterFlip.rect, w, h);
			}
			else
			{
				newBmd = _bmdAfterFlip;
			}
			
			if(oldBmd!=newBmd)
			{
				if(oldBmd && oldBmd!=_bmdAfterFlip && oldBmd!=packageItem.image)
					oldBmd.dispose();
				_content.bitmapData = newBmd;
			}
		}
		
		override public function setup_beforeAdd(xml:XML):void
		{
			super.setup_beforeAdd(xml);
			
			var str:String;
			str = xml.@color;
			if(str)
				this.color = ToolSet.convertFromHtmlColor(str);
			
			str = xml.@flip;
			if(str)
				_flip = FlipType.parse(str);			
		}
	}
}