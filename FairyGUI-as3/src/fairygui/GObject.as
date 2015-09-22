package fairygui
{
	import flash.display.DisplayObject;
	import flash.display.DisplayObjectContainer;
	import flash.display.InteractiveObject;
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.MouseEvent;
	import flash.events.TouchEvent;
	import flash.geom.Point;
	import flash.geom.Rectangle;
	import flash.text.TextField;
	import flash.text.TextFieldType;
	import flash.ui.Mouse;
	import flash.utils.getTimer;
	
	import fairygui.event.DragEvent;
	import fairygui.event.IBubbleEvent;
	import fairygui.event.GTouchEvent;
	import fairygui.utils.GTimers;
	import fairygui.utils.SimpleDispatcher;
	import fairygui.utils.ToolSet;
	
	[Event(name = "startDrag", type = "fairygui.event.DragEvent")]
	[Event(name = "endDrag", type = "fairygui.event.DragEvent")]
	[Event(name = "beginGTouch", type = "fairygui.event.GTouchEvent")]
	[Event(name = "endGTouch", type = "fairygui.event.GTouchEvent")]
	[Event(name = "dragGTouch", type = "fairygui.event.GTouchEvent")]
	[Event(name = "clickGTouch", type = "fairygui.event.GTouchEvent")]
	public class GObject extends EventDispatcher
	{
		public var data:Object;
		
		private var _x:Number;
		private var _y:Number;
		private var _width:Number;
		private var _height:Number;
		private var _pivotX:int;
		private var _pivotY:int;
		private var _alpha:Number;
		private var _rotation:int;
		private var _visible:Boolean;
		private var _touchable:Boolean;
		private var _grayed:Boolean;
		private var _draggable:Boolean;
		private var _scaleX:Number;
		private var _scaleY:Number;
		private var _pivotOffsetX:Number;
		private var _pivotOffsetY:Number;
		private var _alwaysOnTop:int;
		private var _internalVisible:int;
		private var _focusable:Boolean;
		private var _tooltips:String;
		
		private var _relations:Relations;
		private var _group:GGroup;
		private var _gearDisplay:GearDisplay;
		private var _gearXY:GearXY;
		private var _gearSize:GearSize;
		private var _gearLook:GearLook;
		private var _displayObject:DisplayObject;
		private var _dragBounds:Rectangle;
		
		internal var _parent:GComponent;
		internal var _dispatcher:SimpleDispatcher;
		internal var _rawWidth:Number;
		internal var _rawHeight:Number;
		internal var _sourceWidth:int;
		internal var _sourceHeight:int;
		internal var _initWidth:int;
		internal var _initHeight:int;
		internal var _id:String;
		internal var _name:String;
		internal var _packageItem:PackageItem;
		internal var _underConstruct:Boolean;
		internal var _constructingData:XML;
		internal var _gearLocked:Boolean;
		
		internal static var _gInstanceCounter:uint;
		
		internal static const XY_CHANGED:int = 1;
		internal static const SIZE_CHANGED:int = 2;
		internal static const SIZE_DELAY_CHANGE:int = 3;
		
		public function GObject()
		{
			_x = 0;
			_y = 0;
			_width = 0;
			_height = 0;
			_rawWidth = 0;
			_rawHeight = 0;
			_id = "_n" + _gInstanceCounter++;
			_name = "";
			_alpha = 1;
			_rotation = 0;
			_visible = true;
			_internalVisible = 1;
			_touchable = true;
			_scaleX = 1;
			_scaleY = 1;
			_pivotOffsetX = 0;
			_pivotOffsetY = 0;
			
			createDisplayObject();
			
			_relations = new Relations(this);
			_dispatcher = new SimpleDispatcher();
			
			_gearDisplay = new GearDisplay(this);
			_gearXY = new GearXY(this);
			_gearSize = new GearSize(this);
			_gearLook = new GearLook(this);
		}

		final public function get id():String
		{
			return _id;
		}

		final public function get name():String
		{
			return _name;
		}

		final public function set name(value:String):void
		{
			_name = value;
		}

		final public function get x():Number
		{
			return _x;
		}
		
		final public function set x(value:Number):void
		{
			setXY(value, _y);
		}
		
		final public function get y():Number
		{
			return _y;
		}
		
		final public function set y(value:Number):void
		{
			setXY(_x, value);
		}
		
		final public function setXY(xv:Number, yv:Number):void
		{
			if(_x!=xv || _y!=yv)
			{
				var dx:Number = xv-_x;
				var dy:Number = yv-_y;
				_x = xv;
				_y = yv;
				
				handleXYChanged();
				if(this is GGroup)
					GGroup(this).moveChildren(dx, dy);
				
				if(_gearXY.controller)
					_gearXY.updateState();
				
				if(_parent)
				{
					_parent.setBoundsChangedFlag();
					_dispatcher.dispatch(this, XY_CHANGED);
				}
			}
		}
		
		public function center(restraint:Boolean=false):void
		{
			var r:GComponent;
			if (parent != null)
				r = parent;
			else
			{
				r = this.root;
				if (r == null)
					r = GRoot.inst;
			}
			
			this.setXY(int((r.width-this.width)/2), int((r.height-this.height)/2));
			if (restraint)
			{
				this.addRelation(r, RelationType.Center_Center);
				this.addRelation(r, RelationType.Middle_Middle);
			}
		}
		
		final public function get width():Number
		{
			ensureSizeCorrect();
			if(_relations.sizeDirty)
				_relations.ensureRelationsSizeCorrect();
			return _width;
		}
		
		final public function set width(value:Number):void
		{
			setSize(value, _rawHeight);
		}
		
		final public function get height():Number
		{
			ensureSizeCorrect();
			if(_relations.sizeDirty)
				_relations.ensureRelationsSizeCorrect();
			return _height;
		}
		
		final public function set height(value:Number):void
		{
			setSize(_rawWidth, value);
		}
		
		public function setSize(wv:Number, hv:Number, ignorePivot:Boolean = false):void
		{
			if(_rawWidth!=wv || _rawHeight!=hv)
			{
				_rawWidth = wv;
				_rawHeight = hv;
				if(wv<0)
					wv = 0;
				if(hv<0)
					hv = 0;
				var dWidth:Number = wv-_width;
				var dHeight:Number = hv-_height;
				_width = wv;
				_height = hv;
				
				if((_pivotX!=0 || _pivotY!=0) && sourceWidth!=0 && sourceHeight!=0)
				{
					if(!ignorePivot)
						this.setXY(this.x-_pivotX*dWidth/sourceWidth, 
							this.y-_pivotY*dHeight/sourceHeight);
					applyPivot();
				}
				
				handleSizeChanged();
				
				if(_gearSize.controller)
					_gearSize.updateState();
				
				if(_parent)
				{
					_parent.setBoundsChangedFlag();					
					_relations.onOwnerSizeChanged(dWidth, dHeight);
				}
				
				_dispatcher.dispatch(this, SIZE_CHANGED);
			}
		}
		
		public function ensureSizeCorrect():void
		{
		}
		
		final public function get sourceHeight():int
		{
			return _sourceHeight;
		}

		final public function get sourceWidth():int
		{
			return _sourceWidth;
		}
		
		final public function get initHeight():int
		{
			return _initHeight;
		}
		
		final public function get initWidth():int
		{
			return _initWidth;
		}

		final public function get actualWidth():Number
		{
			return this.width*_scaleX;
		}
		
		final public function get actualHeight():Number
		{
			return this.height*_scaleY;
		}		
		
		final public function get scaleX():Number
		{
			return _scaleX;
		}
		
		final public function set scaleX(value:Number):void
		{
			setScale(value, _scaleY);
		}
		
		final public function get scaleY():Number
		{
			return _scaleY;
		}
		
		final public function set scaleY(value:Number):void
		{
			setScale(_scaleX, value);
		}
		
		final public function setScale(sx:Number, sy:Number):void
		{
			if(_scaleX!=sx || _scaleY!=sy)
			{
				_scaleX = sx;
				_scaleY = sy;
				applyPivot();
				handleSizeChanged();
				
				if(_gearSize.controller)
					_gearSize.updateState();
			}
		}
		
		final public function get pivotX():int
		{
			return _pivotX;
		}
		
		final public function set pivotX(value:int):void
		{
			setPivot(value, _pivotY);
		}
		
		final public function get pivotY():int
		{
			return _pivotY;
		}
		
		final public function set pivotY(value:int):void
		{
			setPivot(_pivotX, value);
		}
		
		final public function setPivot(xv:int, yv:int):void
		{
			if(_pivotX!=xv || _pivotY!=yv)
			{
				_pivotX = xv;
				_pivotY = yv;
				
				applyPivot();
			}
		}
		
		private function applyPivot():void
		{
			var ox:Number = _pivotOffsetX;
			var oy:Number = _pivotOffsetY;
			if(_pivotX!=0 || _pivotY!=0)
			{
				var rot:int = this.normalizeRotation;
				if(rot!=0 || _scaleX!=1 || _scaleY!=1)
				{				
					var rotInRad:Number = rot*Math.PI/180;
					var cos:Number = Math.cos(rotInRad);
					var sin:Number = Math.sin(rotInRad);
					var a:Number   = _scaleX *  cos;
					var b:Number   = _scaleX *  sin;
					var c:Number   = _scaleY * -sin;
					var d:Number   = _scaleY *  cos;
					var sx:Number = sourceWidth != 0 ? (_width / sourceWidth) : 1;
					var sy:Number = sourceHeight != 0 ? (_height / sourceHeight) : 1;
					var px:Number = _pivotX*sx;
					var py:Number = _pivotY*sy;
					_pivotOffsetX = px -  (a * px + c * py);
					_pivotOffsetY = py - (d * py + b * px);
				}
				else
				{
					_pivotOffsetX = 0;
					_pivotOffsetY = 0;
				}
			}
			else
			{
				_pivotOffsetX = 0;
				_pivotOffsetY = 0;
			}
			if(ox!=_pivotOffsetX || oy!=_pivotOffsetY)
				handleXYChanged();
		}
		
		final public function get touchable():Boolean
		{
			return _touchable;
		}
		
		public function set touchable(value:Boolean):void
		{
			_touchable = value;
			if((this is GImage) || (this is GMovieClip) 
				|| (this is GTextField) && !(this is GTextInput) && !(this is GRichTextField))
				//Touch is not supported by GImage/GMovieClip/GTextField
				return;
			
			if(_displayObject is InteractiveObject)
			{
				InteractiveObject(_displayObject).mouseEnabled = _touchable;
				if(_displayObject is DisplayObjectContainer)
					DisplayObjectContainer(_displayObject).mouseChildren = _touchable;
			}
		}
		
		final public function get grayed():Boolean
		{
			return _grayed;
		}
		
		public function set grayed(value:Boolean):void
		{
			if(_grayed!=value)
			{
				_grayed = value;
				handleGrayChanged();
				
				if(_gearLook.controller)
					_gearLook.updateState();
			}
		}
		
		final public function get enabled():Boolean
		{
			return !_grayed && _touchable;
		}
		
		public function set enabled(value:Boolean):void
		{
			this.grayed = !value;
			this.touchable = value; 
		}
		
		final public function get rotation():int
		{
			return _rotation;
		}
		
		public function set rotation(value:int):void
		{
			if(_rotation!=value)
			{
				_rotation = value;
				applyPivot();
				
				if(_displayObject)
					_displayObject.rotation = this.normalizeRotation;
				
				if(_gearLook.controller)
					_gearLook.updateState();
			}
		}
		
		public function get normalizeRotation():int
		{
			var rot:int = _rotation%360;
			if(rot>180)
				rot = rot-360;
			else if(rot<-180)
				rot = 360+rot;
			return rot;
		}
		
		final public function get alpha():Number
		{
			return _alpha;
		}
		
		public function set alpha(value:Number):void
		{
			if(_alpha!=value)
			{
				_alpha = value;
				if(_displayObject)
					_displayObject.alpha = _alpha;
				
				if(_gearLook.controller)
					_gearLook.updateState();
			}
		}
		
		final public function get visible():Boolean
		{
			return _visible;
		}
		
		public function set visible(value:Boolean):void
		{
			if(_visible!=value)
			{
				_visible = value;
				if(_displayObject)
					_displayObject.visible = _visible;
				if(_parent)
					_parent.childStateChanged(this);
			}
		}
		
		internal function set internalVisible(value:int):void
		{
			if (value < 0)
				value = 0;
			var oldValue:Boolean = _internalVisible > 0;
			var newValue:Boolean = value > 0;
			_internalVisible = value;
			if (oldValue != newValue)
			{
				if(_parent)
					_parent.childStateChanged(this);
			}
		}
		
		internal function get internalVisible():int
		{
			return _internalVisible;
		}
		
		public function get finalVisible():Boolean
		{
			return _visible && _internalVisible>0 && (!_group || _group.finalVisible);
		}
		
		final public function get alwaysOnTop():int
		{
			return _alwaysOnTop;
		}
		
		public function set alwaysOnTop(value:int):void
		{
			if(value<0)
				value = 0;
			if(_alwaysOnTop!=value)
			{
				var old:int = _alwaysOnTop;
				_alwaysOnTop = value;
				if(_parent!=null)
					_parent.notifyChildAOTChanged(this, old, _alwaysOnTop);
			}
		}
		
		final public function get focusable():Boolean
		{
			return _focusable;
		}
		
		public function set focusable(value:Boolean):void
		{
			_focusable = value;
		}
		
		public function get focused():Boolean
		{
			var r:GRoot = this.root;
			if(r)
				return r.focus == this;
			else
				return false;
		}
		
		public function requestFocus():void
		{
			var r:GRoot = this.root;
			if(r)
			{
				var p:GObject = this;
				while(p && !p._focusable)
					p = p.parent;
				if(p!=null)
					r.focus = p;
			}
		}
		
		final public function get tooltips():String
		{
			return _tooltips;
		}
		
		public function set tooltips(value:String):void
		{
			if(_tooltips && Mouse.supportsCursor)
			{
				this.removeEventListener(MouseEvent.ROLL_OVER, __rollOver);
				this.removeEventListener(MouseEvent.ROLL_OUT, __rollOut);
			}
			
			_tooltips = value;
			if(_tooltips && Mouse.supportsCursor)
			{
				this.addEventListener(MouseEvent.ROLL_OVER, __rollOver);
				this.addEventListener(MouseEvent.ROLL_OUT, __rollOut);
			}
		}
		
		private function __rollOver(evt:Event):void
		{
			var r:GRoot = this.root;
			if(r)
				GTimers.inst.callDelay(100, __doShowTooltips, r);
		}
		
		private function __doShowTooltips(r:GRoot):void
		{
			r.showTooltips(_tooltips);
		}
		
		private function __rollOut(evt:Event):void
		{
			var r:GRoot = this.root;
			if(r)
			{				
				GTimers.inst.remove(__doShowTooltips);
				r.hideTooltips();
			}
		}
		
		final public function get inContainer():Boolean
		{
			return _displayObject!=null && _displayObject.parent!=null;
		}
		
		final public function get onStage():Boolean
		{
			return _displayObject!=null && _displayObject.stage!=null;
		}
		
		final public function get resourceURL():String
		{
			if(_packageItem!=null)
				return "ui://"+_packageItem.owner.id + _packageItem.id;
			else
				return null;
		}
		
		final public function set group(value:GGroup):void
		{
			_group = value;
		}
		
		final public function get group():GGroup
		{
			return _group;
		}

		final public function get gearDisplay():GearDisplay
		{
			return _gearDisplay;
		}
		
		final public function get gearXY():GearXY
		{
			return _gearXY;
		}
		
		final public function get gearSize():GearSize
		{
			return _gearSize;
		}
		
		final public function get gearLook():GearLook
		{
			return _gearLook;
		}
		
		final public function get relations():Relations
		{
			return _relations;
		}
		
		final public function addRelation(target:GObject, relationType:int, usePercent:Boolean = false):void
		{
			_relations.add(target, relationType, usePercent);
		}
	
		final public function removeRelation(target:GObject, relationType:int):void
		{
			_relations.remove(target, relationType);
		}
		
		final public function get displayObject():DisplayObject
		{
			return _displayObject;
		}
		
		final protected function setDisplayObject(value:DisplayObject):void
		{
			_displayObject = value;
		}
		
		final public function get parent():GComponent
		{
			return _parent;
		}
		
		final public function set parent(val:GComponent):void
		{
			_parent = val;
		}
		
		final public function removeFromParent():void
		{
			if(_parent)
				_parent.removeChild(this);
		}
		
		public function get root():GRoot
		{
			var p:GObject = _parent;
			while(p)
			{
				if(p is GRoot)
					return GRoot(p);
				p = p.parent;
			}
			return GRoot.inst;
		}
		
		final public function get asCom():GComponent
		{
			return this as GComponent;
		}
		
		final public function get asButton():GButton
		{
			return this as GButton;
		}
		
		final public function get asLabel():GLabel
		{
			return this as GLabel;
		}
		
		final public function get asProgress():GProgressBar
		{
			return this as GProgressBar;
		}
		
		final public function get asTextField():GTextField
		{
			return this as GTextField;
		}
		
		final public function get asRichTextField():GRichTextField
		{
			return this as GRichTextField;
		}
		
		final public function get asTextInput():GTextInput
		{
			return this as GTextInput;
		}
		
		final public function get asLoader():GLoader
		{
			return this as GLoader;
		}
		
		final public function get asList():GList
		{
			return this as GList;
		}
		
		final public function get asGraph():GGraph
		{
			return this as GGraph;
		}
		
		final public function get asGroup():GGroup
		{
			return this as GGroup;
		}
		
		final public function get asSlider():GSlider
		{
			return this as GSlider;
		}
		
		final public function get asComboBox():GComboBox
		{
			return this as GComboBox;
		}
		
		final public function get asMovieClip():GMovieClip
		{
			return this as GMovieClip;
		}
		
		public function get text():String
		{
			return null;
		}
		
		public function set text(value:String):void
		{
		}
		
		public function dispose():void
		{
			_relations.dispose();
		}

		public function addClickListener(listener:Function):void
		{
			addEventListener(GTouchEvent.CLICK, listener);
		}
		
		public function removeClickListener(listener:Function):void
		{
			removeEventListener(GTouchEvent.CLICK, listener);	
		}
		
		public function hasClickListener():Boolean
		{
			return hasEventListener(GTouchEvent.CLICK);
		}
		
		public function addXYChangeCallback(listener:Function):void
		{
			_dispatcher.addListener(XY_CHANGED, listener);
		}
		
		public function addSizeChangeCallback(listener:Function):void
		{
			_dispatcher.addListener(SIZE_CHANGED, listener);
		}
		
		internal function addSizeDelayChangeCallback(listener:Function):void
		{
			_dispatcher.addListener(SIZE_DELAY_CHANGE, listener);
		}
		
		public function removeXYChangeCallback(listener:Function):void
		{
			_dispatcher.removeListener(XY_CHANGED, listener);
		}
		
		public function removeSizeChangeCallback(listener:Function):void
		{
			_dispatcher.removeListener(SIZE_CHANGED, listener);
		}
		
		internal function removeSizeDelayChangeCallback(listener:Function):void
		{
			_dispatcher.removeListener(SIZE_DELAY_CHANGE, listener);
		}
		
		override public function addEventListener(type:String, listener:Function, useCapture:Boolean=false, priority:int=0, useWeakReference:Boolean=false):void
		{
			super.addEventListener(type, listener, false, priority, useWeakReference);
			
			if(_displayObject!=null)
			{
				if(MTOUCH_EVENTS.indexOf(type)!=-1)
					initMTouch();
				else
				{
					if(type=="rightClick" && (this is GComponent))
						GComponent(this).opaque = true;
					
					_displayObject.addEventListener(type, _reDispatch, useCapture, priority, useWeakReference);
				}
			}
		}
		
		override public function removeEventListener(type:String, listener:Function, useCapture:Boolean=false):void
		{
			super.removeEventListener(type, listener, false);

			if(_displayObject!=null && !this.hasEventListener(type))
			{
				_displayObject.removeEventListener(type, _reDispatch, true);
				_displayObject.removeEventListener(type, _reDispatch, false);
			}
		}
		
		private function _reDispatch(evt:Event):void
		{
			var nevt:Event = evt.clone();
			this.dispatchEvent(nevt);
			if(evt.bubbles && (nevt is IBubbleEvent) && IBubbleEvent(nevt).propagationStopped)
				evt.stopPropagation();
		}
		
		final public function get draggable():Boolean
		{
			return _draggable;
		}
		
		final public function set draggable(value:Boolean):void
		{
			if (_draggable != value)
			{
				_draggable = value;
				initDrag();
			}
		}
		
		final public function get dragBounds():Rectangle
		{
			return _dragBounds;
		}
		
		final public function set dragBounds(value:Rectangle):void
		{
			_dragBounds = value;
		}
		
		public function startDrag(bounds:Rectangle=null, touchPointID:int=-1):void
		{
			if (_displayObject.stage==null)
				return;
			
			dragBegin(null);
			triggerDown(touchPointID);
		}
		
		public function stopDrag():void
		{
			dragEnd();
		}
		
		public function get dragging():Boolean
		{
			return sDragging==this;
		}
		
		public function localToGlobal(ax:Number=0, ay:Number=0):Point
		{
			sHelperPoint.x = ax*GRoot.contentScaleFactor;
			sHelperPoint.y = ay*GRoot.contentScaleFactor;
			var ret:Point = _displayObject.localToGlobal(sHelperPoint);
			ret.x /= GRoot.contentScaleFactor;
			ret.y /= GRoot.contentScaleFactor;
			return ret;
		}
		
		public function globalToLocal(ax:Number=0, ay:Number=0):Point
		{
			sHelperPoint.x = ax*GRoot.contentScaleFactor;
			sHelperPoint.y = ay*GRoot.contentScaleFactor;
			var ret:Point = _displayObject.globalToLocal(sHelperPoint);
			ret.x /= GRoot.contentScaleFactor;
			ret.y /= GRoot.contentScaleFactor;
			return ret;
		}
		
		public function getGlobalRect(rect:Rectangle):Rectangle
		{
			if(rect==null)
				rect = new Rectangle();
			var pt:Point = this.localToGlobal();
			rect.x = pt.x;
			rect.y = pt.y;
			pt = this.localToGlobal(this.width, this.height);
			rect.right = pt.x;
			rect.bottom = pt.y;
			return rect;
		}
		
		protected function createDisplayObject():void
		{
			
		}

		protected function handleXYChanged():void
		{
			if(_displayObject)
			{
				_displayObject.x = int((_x+_pivotOffsetX)*GRoot.contentScaleFactor);
				_displayObject.y = int((_y+_pivotOffsetY)*GRoot.contentScaleFactor);
			}
		}
		
		protected function handleSizeChanged():void
		{
		}
		
		public function handleControllerChanged(c:Controller):void
		{
			if(_gearDisplay.controller==c)
				_gearDisplay.apply();
			if(_gearXY.controller==c)
				_gearXY.apply();
			if(_gearSize.controller==c)
				_gearSize.apply();
			if(_gearLook.controller==c)
				_gearLook.apply();
		}
		
		protected function handleGrayChanged():void
		{
			if(_displayObject)
			{
				if(_grayed)
					_displayObject.filters = ToolSet.GRAY_FILTERS;
				else
					_displayObject.filters = null;
			}	
		}
		
		public function constructFromResource(pkgItem:PackageItem):void
		{
			_packageItem = pkgItem;
		}

		public function setup_beforeAdd(xml:XML):void
		{
			var str:String;
			var arr:Array;
			
			_id = xml.@id;
			_name = xml.@name;
			
			str = xml.@xy;
			arr = str.split(",");
			this.setXY(parseInt(arr[0]), parseInt(arr[1]));
			
			str = xml.@size;
			if(str)
			{
				arr = str.split(",");
				_initWidth = parseInt(arr[0]);
				_initHeight = parseInt(arr[1]);
				setSize(_initWidth,_initHeight);
			}
			
			str = xml.@scale;
			if(str)
			{
				arr = str.split(",");
				setScale(parseFloat(arr[0]), parseFloat(arr[1]));
			}
			
			str = xml.@rotation;
			if(str)
				this.rotation = parseInt(str);
			
			str = xml.@alpha;
			if(str)
				this.alpha = parseFloat(str);
			
			str = xml.@pivot;
			if(str)
			{
				arr = str.split(",");
				this.setPivot(int(arr[0]), int(arr[1]));
			}
			
			this.touchable = xml.@touchable!="false";
			this.visible = xml.@visible!="false";
			this.grayed = xml.@grayed=="true";			
			this.tooltips = xml.@tooltips;
		}
		
		public function setup_afterAdd(xml:XML):void
		{
			var cxml:XML;
			
			var s:String = xml.@group;
			if(s)
				_group = _parent.getChildById(s) as GGroup;
			
			cxml = xml.gearDisplay[0];
			if(cxml)
				_gearDisplay.setup(cxml);
			
			cxml = xml.gearXY[0];
			if(cxml)
				_gearXY.setup(cxml);
			
			cxml = xml.gearSize[0];
			if(cxml)
				_gearSize.setup(cxml);
			
			cxml = xml.gearLook[0];
			if(cxml)
				_gearLook.setup(cxml);
		}
		
		//touch support
		//-------------------------------------------------------------------
		private var _touchPointId:int;
		private var _lastClick:int;
		private var _buttonStatus:int;
		private static const MTOUCH_EVENTS:Array = 
			[GTouchEvent.BEGIN, GTouchEvent.DRAG, GTouchEvent.END, GTouchEvent.CLICK];
		
		public function get isDown():Boolean
		{
			return _buttonStatus==1;
		}
		
		public function triggerDown(touchPointID:int=-1):void
		{
			_buttonStatus = 1;
			if(!GRoot.touchPointInput)
			{
				_displayObject.stage.addEventListener(MouseEvent.MOUSE_UP, __stageMouseup, false, 20);
				if(hasEventListener(GTouchEvent.DRAG))
					_displayObject.stage.addEventListener(MouseEvent.MOUSE_MOVE, __mousemove);
			}
			else
			{
				_touchPointId = touchPointID;
				_displayObject.stage.addEventListener(TouchEvent.TOUCH_END, __stageMouseup, false, 20);
				if(hasEventListener(GTouchEvent.DRAG))
					_displayObject.stage.addEventListener(TouchEvent.TOUCH_MOVE, __mousemove);
			}
		}
		
		private function initMTouch():void
		{
			if(this is GComponent)
			{	/*GComponent is by default not opaque for optimization.
				if a click listener registered, we set opaque to true
				*/
				GComponent(this).opaque = true;
			}
			if(!GRoot.touchPointInput)
			{
				_displayObject.addEventListener(MouseEvent.MOUSE_DOWN, __mousedown);
				_displayObject.addEventListener(MouseEvent.MOUSE_UP, __mouseup);
			}
			else
			{
				_displayObject.addEventListener(TouchEvent.TOUCH_BEGIN, __mousedown);
				_displayObject.addEventListener(TouchEvent.TOUCH_END, __mouseup);
			}
		}
		
		private function __mousedown(evt:Event):void
		{
			var devt:GTouchEvent = new GTouchEvent(GTouchEvent.BEGIN);
			devt.copyFrom(evt);
			this.dispatchEvent(devt);
			if(devt.isPropagationStop)
				evt.stopPropagation();
			
			if(!GRoot.touchPointInput)
				triggerDown();
			else
				triggerDown(TouchEvent(evt).touchPointID);
		}
		
		private function __mousemove(evt:Event):void
		{
			if(_buttonStatus!=1
				|| GRoot.touchPointInput && _touchPointId!=TouchEvent(evt).touchPointID)
				return;
			
			var devt:GTouchEvent = new GTouchEvent(GTouchEvent.DRAG);
			devt.copyFrom(evt);
			this.dispatchEvent(devt);
			if(devt.isPropagationStop)
				evt.stopPropagation();
		}
		
		private function __mouseup(evt:Event):void
		{
			if(_buttonStatus!=1
				|| GRoot.touchPointInput && _touchPointId!=TouchEvent(evt).touchPointID)
				return;
			
			_buttonStatus = 2;
		}
		
		private function __stageMouseup(evt:Event):void
		{
			if(!GRoot.touchPointInput)
			{
				evt.currentTarget.removeEventListener(MouseEvent.MOUSE_UP, __stageMouseup);
				evt.currentTarget.removeEventListener(MouseEvent.MOUSE_MOVE, __mousemove);
			}
			else
			{
				if(_touchPointId!=TouchEvent(evt).touchPointID)
					return;
				
				evt.currentTarget.removeEventListener(TouchEvent.TOUCH_END, __stageMouseup);
				evt.currentTarget.removeEventListener(TouchEvent.TOUCH_MOVE, __mousemove);
			}
			
			if(_buttonStatus==2)
			{
				var cc:int = 1;
				var now:int = getTimer();
				if(now-_lastClick<500)
				{
					cc = 2;
					_lastClick = 0;
				}
				else
					_lastClick = now;

				var devt:GTouchEvent = new GTouchEvent(GTouchEvent.CLICK);
				devt.copyFrom(evt, cc);

				this.dispatchEvent(devt);
			}
			
			_buttonStatus = 0;
			
			devt = new GTouchEvent(GTouchEvent.END);
			devt.copyFrom(evt);
			this.dispatchEvent(devt);
		}
		//-------------------------------------------------------------------
		
		//drag support
		//-------------------------------------------------------------------
		private static var sDragging:GObject;
		private static var sGlobalDragStart:Point = new Point();
		private static var sGlobalRect:Rectangle = new Rectangle();
		private static var sHelperPoint:Point = new Point();
		
		private function initDrag():void
		{
			if(_draggable)
				addEventListener(GTouchEvent.BEGIN, __begin);
			else
				removeEventListener(GTouchEvent.BEGIN, __begin);
		}
		
		private function dragBegin(evt:GTouchEvent):void
		{
			if(sDragging!=null)
				sDragging.stopDrag();
			
			if(evt!=null)
			{
				sGlobalDragStart.x = evt.stageX/GRoot.contentScaleFactor;
				sGlobalDragStart.y = evt.stageY/GRoot.contentScaleFactor;
			}
			else
			{
				sGlobalDragStart.x = _displayObject.stage.mouseX/GRoot.contentScaleFactor;
				sGlobalDragStart.y = _displayObject.stage.mouseY/GRoot.contentScaleFactor;
			}
			getGlobalRect(sGlobalRect);
			sDragging = this;
			
			addEventListener(GTouchEvent.DRAG, __dragging);
			addEventListener(GTouchEvent.END, __dragEnd);
		}
		
		private function dragEnd():void
		{
			if (sDragging==this)
			{
				removeEventListener(GTouchEvent.DRAG, __dragStart);
				removeEventListener(GTouchEvent.END, __dragEnd);
				removeEventListener(GTouchEvent.DRAG, __dragging);
				sDragging = null;
			}
		}
		
		private function __begin(evt:GTouchEvent):void
		{
			if((evt.realTarget is TextField) && TextField(evt.realTarget).type==TextFieldType.INPUT)
				return;
			
			addEventListener(GTouchEvent.DRAG, __dragStart);
		}
		
		private function __dragStart(evt:GTouchEvent):void
		{
			removeEventListener(GTouchEvent.DRAG, __dragStart);
			
			if((evt.realTarget is TextField) && TextField(evt.realTarget).type==TextFieldType.INPUT)
				return;
			
			var dragEvent:DragEvent = new DragEvent(DragEvent.DRAG_START);
			dragEvent.stageX = evt.stageX;
			dragEvent.stageY = evt.stageY;
			dragEvent.touchPointID = evt.touchPointID;
			dispatchEvent(dragEvent);
			
			if (!dragEvent.isDefaultPrevented())
				dragBegin(evt);
		}
		
		private function __dragging(evt:GTouchEvent):void
		{				
			if(this.parent==null)
				return;
			
			var xx:Number = evt.stageX/GRoot.contentScaleFactor - sGlobalDragStart.x + sGlobalRect.x;
			var yy:Number = evt.stageY/GRoot.contentScaleFactor - sGlobalDragStart.y　+ sGlobalRect.y;
			
			if (_dragBounds!=null)
			{
				if (xx < _dragBounds.x)
					xx = _dragBounds.x;
				else if(xx + sGlobalRect.width > _dragBounds.right)
				{
					xx = _dragBounds.right - sGlobalRect.width;
					if (xx < _dragBounds.x)
						xx = _dragBounds.x;
				}

				if(yy < _dragBounds.y)
					yy = _dragBounds.y;
				else if(yy + sGlobalRect.height > _dragBounds.bottom)
				{
					yy = _dragBounds.bottom - sGlobalRect.height;
					if(yy < _dragBounds.y)
						yy = _dragBounds.y;
				}
			}
			
			var pt:Point = this.parent.globalToLocal(xx, yy);
			this.setXY(Math.round(pt.x), Math.round(pt.y));
		}
		
		private function __dragEnd(evt:GTouchEvent):void
		{
			if (sDragging==this)
			{
				stopDrag();
				
				var dragEvent:DragEvent = new DragEvent(DragEvent.DRAG_END);
				dragEvent.stageX = evt.stageX;
				dragEvent.stageY = evt.stageY;
				dragEvent.touchPointID = evt.touchPointID;
				dispatchEvent(dragEvent);
			}
		}
		//-------------------------------------------------------------------
	}
}