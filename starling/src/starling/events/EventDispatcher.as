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
    import flash.events.IEventDispatcher;
    import flash.utils.Dictionary;
    
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
        
        /** Helper object. */
        private static var sBubbleChains:Array = [];
        
        /** Creates an EventDispatcher. */
        public function EventDispatcher(target:IEventDispatcher=null)
        {  
			super(target);
		}
        
        /** Registers an event listener at a certain object. */
        override public function addEventListener(type:String, listener:Function, useCapture:Boolean = false, priority:int = 0, useWeakReference:Boolean = false):void
        {
			if (useCapture){
				//TODO realize useCapture functionality
				throw new Error ("starling.events.EventDispatcher#addEventListener don't use true value for useCapture parameter");
			}
			
            if (mEventListeners == null)
                mEventListeners = {};
            
            var listeners:Vector.<Listener> = mEventListeners[type] as Vector.<Listener>;
            if (listeners == null)
                mEventListeners[type] = new <Listener>[new Listener(listener, useCapture, priority, useWeakReference)];
           	else {
				var i:int;
				var index:int = -1;
				var len:uint = listeners.length;
				
				var newListener:Listener;
				var prevListener:Listener;
				var currentListener:Listener;
				
				var shift:Boolean = false;
				
				//indexOf				
				for (i = 0; i < len; i++){
					currentListener = listeners[i];
					if ( currentListener.listener == listener){
						index = i;
						break;
					}
				}		
				
				if (index == -1) {
					newListener = new Listener(listener, useCapture, priority, useWeakReference);
				} else {
					return;
				}
				
				// slice
				for (i = 0; i < len; i++){
					currentListener = listeners[i];							
					if (shift) {
						listeners[i] = prevListener;
						prevListener = currentListener;
					} else  if(currentListener.priority < priority) {					
						shift = true;
						prevListener = currentListener;
						listeners[i] = newListener;				
					}
				}
				
				// push
				if(shift) {		
					listeners[len] = prevListener;	
				} else {
					listeners[len] = newListener;
				}
			}
			
			super.addEventListener(type, listener, useCapture, priority, useWeakReference);
        }
        
        /** Removes an event listener from the object. */
        override public function removeEventListener(type:String, listener:Function, useCapture:Boolean = false):void
        {		
            if (mEventListeners)
            {
                var listeners:Vector.<Listener> = mEventListeners[type] as Vector.<Listener>;
                if (listeners)
                {
                    var numListeners:int = listeners.length;
                    var remainingListeners:Vector.<Listener> = new <Listener>[];
                    
                    for (var i:int=0; i<numListeners; ++i)
                        if (listeners[i].func != listener) remainingListeners.push(listeners[i]);
                    
                    mEventListeners[type] = remainingListeners;
                }
            }
			super.removeEventListener(type,listener, useCapture);
        }
        
        /** Removes all event listeners with a certain type, or all of them if type is null. 
         *  Be careful when removing all event listeners: you never know who else was listening. */
        public function removeEventListeners(type:String=null):void
		{	if ( !this.mEventListeners )
				return;
			
			var listeners:	Vector.<Listener>;
			var len:		uint;
			
			for (var key:String in this.mEventListeners) {
				if (key == type || !type) {
					
					listeners = mEventListeners[key] as Vector.<Listener>;
					len = listeners.length;
					
					for (var i:uint = 0; i < len; i++)
						super.removeEventListener(key, listeners[i].func);
					if (key == type) {
						delete mEventListeners[key];
						return;
					}
					
				}
			}
			
			if ( !type )
				mEventListeners = null;
		
        }
        
        /** Dispatches an event to all objects that have registered listeners for its type. 
         *  If an event with enabled 'bubble' property is dispatched to a display object, it will 
         *  travel up along the line of parents, until it either hits the root object or someone
         *  stops its propagation manually. */
        override public function dispatchEvent(event:flash.events.Event):Boolean
        {	
			if (!(event is starling.events.Event)) 
				if (!event.bubbles){
					return super.dispatchEvent(event);
				} else { 	
					throw new IllegalOperationError("Bubbling Event must be starling.events.Event or must extends it");
					//TODO: May be always dispatch it? 
				}
			
			const starlingEvent:starling.events.Event = event as starling.events.Event;
            var bubbles:Boolean = starlingEvent.bubbles;
            
            if (!bubbles && (mEventListeners == null || !(event.type in mEventListeners)))
                return true; // no need to do anything
            
            // we save the current target and restore it later;
            // this allows users to re-dispatch events without creating a clone.
            
            var previousTarget:starling.events.EventDispatcher = starlingEvent.target as starling.events.EventDispatcher;
            starlingEvent.setTarget(this);
            
            if (bubbles && this is DisplayObject) bubbleEvent(starlingEvent);
            else                                  invokeEvent(starlingEvent);
            
            if (previousTarget) starlingEvent.setTarget(previousTarget);
			
			return true;
        }
        
        /** @private
         *  Invokes an event on the current object. This method does not do any bubbling, nor
         *  does it back-up and restore the previous target on the event. The 'dispatchEvent' 
         *  method uses this method internally. */
        internal function invokeEvent(event:starling.events.Event):Boolean
		{ 			
            var listeners:Vector.<Listener> = mEventListeners ?
                mEventListeners[event.type] as Vector.<Listener> : null;
            var numListeners:int = listeners == null ? 0 : listeners.length;
            
            if (numListeners)
            {
                event.setCurrentTarget(this);
                
                // we can enumerate directly over the vector, because:
                // when somebody modifies the list while we're looping, "addEventListener" is not
                // problematic, and "removeEventListener" will create a new Vector, anyway.
                
                for (var i:int=0; i<numListeners; ++i)
                {
                    var listener:Listener = listeners[i];
					var func:Function = listener.func;
					if (func == null) continue;
                    var numArgs:int = func.length;
                    
                    if (numArgs == 0) func();
                    else if (numArgs == 1) func(event);
                    else func(event, event.data);
                    
                    if (event.stopsImmediatePropagation)
                        return true;
                }
                
                return event.stopsPropagation;
            }
            else
            {
                return false;
            }
        }
        
        /** @private */
        internal function bubbleEvent(event:starling.events.Event):void
        {
            // we determine the bubble chain before starting to invoke the listeners.
            // that way, changes done by the listeners won't affect the bubble chain.
            
            var chain:Vector.<starling.events.EventDispatcher>;
            var element:DisplayObject = this as DisplayObject;
            var length:int = 1;
            
            if (sBubbleChains.length > 0) { chain = sBubbleChains.pop(); chain[0] = element; }
            else chain = new <starling.events.EventDispatcher>[element];
            
            while ((element = element.parent) != null)
                chain[int(length++)] = element;

            for (var i:int=0; i<length; ++i)
            {
                var stopPropagation:Boolean = chain[i].invokeEvent(event);
                if (stopPropagation) break;
            }
            
            chain.length = 0;
            sBubbleChains.push(chain);
        }
        
        /** Dispatches an event with the given parameters to all objects that have registered 
         *  listeners for the given type. The method uses an internal pool of event objects to 
         *  avoid allocations. */
        public function dispatchEventWith(type:String, bubbles:Boolean=false, data:Object=null):void
        {
            if (bubbles && willTrigger(type) || hasEventListener(type)) 
            {
                var event:starling.events.Event = starling.events.Event.fromPool(type, bubbles, data);
                dispatchEvent(event);
				starling.events.Event.toPool(event);
            }
        }
		
		/** Returns if there are listeners registered for a certain event type on this object or
		 *  on any objects that an event of the specified type can bubble to. */
		override public function willTrigger(type:String):Boolean
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
    }
}

import flash.utils.Dictionary;

internal class Listener {
	
	public function Listener(func:Function, useCapture:Boolean, priority:int, useWeakReference:Boolean) 
	{
		if (useWeakReference) 
		{
			mDict = new Dictionary(true);
			mDict[func] = true;
		} else {
			this.listener = func;
		}
		this.priority = priority;
		this.useCapture = useCapture;
	}
	
	public var listener:Function = null;
	public var priority:int;
	public var useCapture:Boolean;
	
	private var mDict:Dictionary = null;
	
	public function get func():Function 
	{
		if (listener)
			return listener;
		for(var item:Object in mDict)
			return item as Function;
		return null;
	}
	public function toString():String{
		return String(priority);
	}
}