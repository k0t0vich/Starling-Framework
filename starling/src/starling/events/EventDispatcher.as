// =================================================================================================
//
//	Starling Framework
//	Copyright 2011 Gamua OG. All Rights Reserved.
//
//	This program is free software. You can redistribute and/or modify it
//	in accordance with the terms of the accompanying license agreement.
//
// =================================================================================================

package starling.events
{
    import flash.errors.IllegalOperationError;
    import flash.events.Event;
    import flash.events.EventDispatcher;
    import flash.events.EventPhase;
    import flash.events.IEventDispatcher;
	
    import starling.core.starling_internal;
    import starling.display.DisplayObject;
    
    use namespace starling_internal;
    
    /** The EventDispatcher class is the base class for all classes that dispatch events. 
     *  This is the Starling version of the Flash class with the same name. 
     *  
     *  <p>The event mechanism is a key feature of Starling's architecture. Objects can communicate 
     *  with each other through events. Compared the the Flash event system, Starling's event system
     *  was simplified. The main difference is that Starling events have no "Capture" phase.
     *  They are simply dispatched at the target and may optionally bubble up. They cannot move 
     *  in the opposite direction.</p>  
     *  
     *  <p>As in the conventional Flash classes, display objects inherit from EventDispatcher 
     *  and can thus dispatch events. Beware, though, that the Starling event classes are 
     *  <em>not compatible with Flash events:</em> Starling display objects dispatch 
     *  Starling events, which will bubble along Starling display objects - but they cannot 
     *  dispatch Flash events or bubble along Flash display objects.</p>
     *  
     *  @see Event
     *  @see starling.display.DisplayObject DisplayObject
     */
    public class EventDispatcher extends flash.events.EventDispatcher
    {		
        private var mEventListeners:Object;
        
        /** Creates an EventDispatcher. */
        public function EventDispatcher(target:IEventDispatcher=null)
        {  
			super(target);
		}
        
		
        /**
         * Registers an event listener at a certain object.
         * @param type
         * @param listener
         * @param useCapture - unused
         * @param priority
         * @param useWeakReference use weak reference
		 * don't saving reference if useWeakReference==true, but method removeEventListeners will not remove this listener, you will remove it manualy with removeEventListener method 
         * @throws ArgumentError
         */
        override public function addEventListener(type:String, listener:Function, useCapture:Boolean = false, priority:int = 0, useWeakReference:Boolean = false):void
        {
			// For debugging you app listeners uncomment this
			/*if(listener.length != 1){
				throw new ArgumentError("starling.events.EventDispatcher#addEventListener argument listener must have a one parameter " + listener.length);
			}*/
			
			if (useCapture)
			{
				//TODO realize useCapture functionality
				throw new ArgumentError ("starling.events.EventDispatcher#addEventListener don't use true value for useCapture parameter");
			}
			
			if (!useWeakReference)
			{
				if (mEventListeners == null)
					mEventListeners = {};
				
				var listeners:Vector.<Function> = mEventListeners[type] as Vector.<Function>;
				if (listeners == null)
					mEventListeners[type] = new <Function>[listener];
				else if (listeners.indexOf(listener) == -1) 
				{	// check for duplicates
					listeners.push(listener);
				}
			}
			super.addEventListener(type, listener, useCapture, priority, useWeakReference);
        }
        
        /** Removes an event listener from the object. */
        override public function removeEventListener(type:String, listener:Function, useCapture:Boolean = false):void
        {		
			if (useCapture)
			{
				throw new Error ("starling.events.EventDispatcher#removeEventListener don't use true value for useCapture parameter");
			}
            if (mEventListeners)
            {
                var listeners:Vector.<Function> = mEventListeners[type] as Vector.<Function>;
                if (listeners)
                {
                    var numListeners:int = listeners.length;
                    var remainingListeners:Vector.<Function> = new <Function>[];
                    
                    for (var i:int=0; i<numListeners; ++i)
                        if (listeners[i] != listener) remainingListeners.push(listeners[i]);
                    
                    mEventListeners[type] = remainingListeners;
                }
            }
			super.removeEventListener(type, listener, useCapture);
        }
		
		
		/** Dispatches an event to all objects that have registered listeners for its type. 
		 *  If an event with enabled 'bubble' property is dispatched to a display object, it will 
		 *  travel up along the line of parents, until it either hits the root object or someone
		 *  stops its propagation manually. */
		override public function dispatchEvent(event:flash.events.Event):Boolean
		{
			if ( event.bubbles ) 
			{
				if ( event is starling.events.Event ) 
					return bubbleEvent( event as starling.events.Event );
				else 
					throw new TypeError( 'Bubbling Event must be starling.events.Event or must extends it' );
				//TODO: May be anyway dispatch it? 
			} 
			else 
				return super.dispatchEvent(event);
		}	
		
		/** Returns if there are listeners registered for a certain event type on this object or
		 *  on any objects that an event of the specified type can bubble to. */	
		public override function willTrigger(type:String):Boolean 
		{
			var element:DisplayObject = this as DisplayObject;
			if(!element)
			{
				return super.hasEventListener(type);
			}
			do
			{
				if(element.hasEventListener(type))
				{
					return true;
				}
			}
			while ((element = element.parent) != null)
			return false;
		}
			
		/** Dispatches an event with the given parameters to all objects that have registered 
		 *  listeners for the given type. */
		public function dispatchEventWith(type:String, bubbles:Boolean=false, data:Object=null):void
		{
			if (super.hasEventListener(type) || bubbles && willTrigger(type)) 
			{
				var event:starling.events.Event = new starling.events.Event(type, bubbles, data);
				dispatchEvent(event);
			}
		}
        
        /** Removes all event listeners with a certain type, or all of them if type is null. 
         *  Be careful when removing all event listeners: you never know who else was listening. */
        public function removeEventListeners(type:String=null):void
        {
			if ( !this.mEventListeners )
				return;
				
				var listeners:        Vector.<Function>;
				var len:                uint;
				
				for (var key:String in this.mEventListeners) 
				{
					if (key == type || !type) 
					{
						
						listeners = mEventListeners[key] as Vector.<Function>;
						len = listeners.length;
						
						for (var i:uint = 0; i < len; i++)
							super.removeEventListener(key, listeners[i]);
						if (key == type) 
						{
							delete mEventListeners[key];
							return;
						}	
					}
				}
				
				if ( !type )
					mEventListeners = null;
        } 
			
		/** @private
		 *  Invokes an clone of event with previous target on the current object. This method does not do any bubbling, nor
		 *  does it back-up. */
		internal function invokeEvent(event:starling.events.Event):Boolean
		{ 	
			if (hasEventListener(event.type))
			{
				var target:EventDispatcher = event.target as EventDispatcher;
				if(!target || target == this) 
				{
					return !super.dispatchEvent(event);
				}
				var clone:starling.events.Event = event.clone() as starling.events.Event;
				clone.setTarget(target);
				CONTAINER.$event = clone;
				return !super.dispatchEvent(CONTAINER);			
			}
			return false;
		}

        private function $dispathEvent(event:starling.events.Event):Boolean
		{ 		
			return super.dispatchEvent(event);
        }
    
        /** @private */
        private function bubbleEvent(event:starling.events.Event):Boolean
        {
			var canceled:Boolean = false;
			if ( super.hasEventListener(event.type)) 
			{
				canceled = !super.dispatchEvent(event);
			}
			if (!event.stopsPropagation) 
			{
				var target:starling.events.EventDispatcher = (this as DisplayObject).parent;
				while (target) 
				{
					if (target.hasEventListener(event.type)) 
					{
						var bubbleEvent:starling.events.Event = event.clone() as starling.events.Event;
						bubbleEvent.setEventPhase(EventPhase.BUBBLING_PHASE);
						bubbleEvent.setTarget(this);
						bubbleEvent.setCanceled(canceled);
						CONTAINER.$event = bubbleEvent;
						target.$dispathEvent( CONTAINER );	
						canceled = bubbleEvent.canceled;
						if (bubbleEvent.stopsPropagation) 
							break;
					}
					target = (target as DisplayObject).parent;
				}
			}
			return !canceled;
        }
	
	}
}

// hook for replace target
import flash.events.Event;
internal final class EventContainer extends Event 
{
	private static const TARGET:Object = new Object();
	
	internal var $event:Event;
	
	public function EventContainer() 
	{
		super( '', true );
	}

	public override function get target():Object 
	{
		return TARGET;
	}
	
	public override function clone():Event 
	{
		return this.$event;
	}
	
}

internal const CONTAINER:EventContainer = new EventContainer();