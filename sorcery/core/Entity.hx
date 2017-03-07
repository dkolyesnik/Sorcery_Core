/**
 * Created by Dmitriy Kolesnik on 02.08.2016.
 */
package sorcery.core;

import sorcery.core.BaseAgenda;
import sorcery.core.abstracts.Agenda;
import sorcery.core.abstracts.ComponentName;
import sorcery.core.abstracts.EntityName;
import sorcery.core.abstracts.FullName;
import sorcery.core.interfaces.IAgendaChild;
import sorcery.core.interfaces.IAgendaManager;
import sorcery.core.interfaces.ICloneable;
import sorcery.core.interfaces.IComponent;
import sorcery.core.interfaces.ICore;
import sorcery.core.interfaces.IEntity;
import haxecontracts.Contract;
import haxecontracts.HaxeContracts;

import sorcery.core.interfaces.IEntityChild;
import sorcery.core.interfaces.IEntityGroup;
import sorcery.core.interfaces.IEvent;
import sorcery.core.interfaces.INotificator;
import sorcery.core.interfaces.IPool;
import sorcery.core.interfaces.IPoolable;

using sorcery.core.tools.EntityTools;

/**
 * Basic object, can have children GameObjects and components
 */
@:allow(sorcery.core.interfaces.IEntityGroup)
@:access(sorcery.core.interfaces.IEntity)
@:access(sorcery.core.interfaces.IEntityChild)
@:access(sorcery.core.interfaces.IComponent)
class Entity extends sorcery.core.EntityChild implements IEntity implements IPoolable implements IAgendaManager implements HaxeContracts
{
	/**
	 * full name of the entity, unique identifier with consists of the groups's full name plus entity name
	 * it looks like #.group1.group2.name
	 * if entity is not added to root it's full name is null (? maybe it would be better to use something else ?)
	 */
	public var fullName(get, never) : String;
	public var group(get, null) : IEntityGroup;
	public var agenda(get, never) : IAgendaManager;
	@:isVar
	public var enabled(get, set) : Bool = true;

	var _pool : IPool;

	var _isDestroyed = false;

	//CHILDREN
	var _children : Array<IEntityChild>;
	var _childrenByName : Map<String, IEntityChild>;

	var _activeAgendas:Array<String>;

	public function new(p_core:ICore)
	{
		Contract.requires(p_core != null);
		Contract.ensures(core == p_core && _isActivatedByParent == _isActive == _isAddedToRoot == _isFocused == _isDestroyed == false);

		super(p_core);
		_isDestroyed = false;
		_childrenByName = new Map();
		_children = [];
		_activeAgendas = [BaseAgenda.ALWAYS];
	}

	override public function setName(p_name:String):IEntityChild 
	{
		Contract.requires(EntityName.validate(p_name));
		
		return super.setName(p_name);
	}
	
	// ==============================================================================
	// GETTERS & SETTERS
	// ==============================================================================
	function get_agenda() : IAgendaManager
	{
		return this;
	}

	function get_enabled():Bool
	{
		return enabled;
	}

	function set_enabled(value : Bool) : Bool
	{
		if (enabled == value)
		{
			return value;
		}

		enabled = value;

		return value;
	}

	function get_group():IEntityGroup
	{
		return group;
	}

	function get_fullName():String
	{
		Contract.ensures(Contract.result == null || FullName.validate(Contract.result));
		
		if (!isAddedToRoot())
			return null;

		return group.fullName + "." + name;
	}

	// ==============================================================================
	// METHODS
	// ==============================================================================
	public function isWrapped():Bool
	{
		return group != null ? group.name == name : false;
	}
	
	public function isGroup():Bool
	{
		return false;
	}
	
	override public function destroy() : Void
	{
		Contract.ensures(_children.length == 0);

		while (_children.length > 0)
		{
			_children.shift().destroy();
		}
		_childrenByName = new Map();

		if (_pool != null)
		{
			_pool.putBackObject(this);
		}
	}

	//CHILDREN

	public function addChild(child : IEntityChild) : IEntityChild
	{
		Contract.requires(child != null);
		Contract.ensures(EntityTools.checkWhetherChildCanBeAdded(this, child));
		Contract.ensures(_children.indexOf(child) >= 0);
		Contract.ensures(child.parent == this);
		
		//adding as not active child
		if (child.isEntity())
		{
			var entity:IEntity = cast child;
			if (entity.name == null || entity.name == "")
			{
				entity.setName(core.factory.generateName());
			}
			if (entity.isWrapped())
				child = cast entity.group;
		}

		if (child.parent != null)
		{
			if (child.parent == this)
			{
				return child;
			}
			else
			{
				child.parent.removeChild(child);
			}
		}
		_children.push(child);
		child.addToParent(this);
		
		//update useByAgendaCound
		for (agenda in _agendas)
			child.activateByAgenda(agenda);
			
		//adding to root if this entity is added to root and child is used by agenda
		if (_isAddedToRoot && child.getUseByAgendaCount() > 0)
		{
			_addChildToRoot(child);
				
			child.activate();
			
			if (child.hasAgenda(getCurrentAgenda()))
				child.setFocus(true);
		}
		
		return child;
	}
	
	public function removeChild(child : IEntityChild) : IEntityChild
	{
		Contract.requires(child != null);
		Contract.requires(child.parent == this);
		Contract.ensures(_children.indexOf(child) == -1);
		Contract.ensures(child.parent == null && child.isActivatedByParent() == false && child.isActive() == false && child.isAddedToRoot() == false);
		
		
		if (child.parent != this)
			return child;
			
		if (child.isEntity())
		{
			//get wrapper if entity is wrapped in a group
			var ent:IEntity = cast child;
			if (ent.isWrapped())
				ent = cast ent.group;
			child = ent;
		}
		_deactivateChild(child);
		child.onRemovedFromParent();
		if (_children.remove(child))
		{
			updateChildrenAgendaState();
			return child;
		}
		return child;
	}

	public function findChild(p_name:String):IEntityChild
	{
		Contract.requires(ComponentName.validate(p_name) || EntityName.validate(p_name));
 		
		return _childrenByName[p_name];
	}

	public function sendEvent(event : IEvent) : Void
	{
		Contract.requires(event != null);
		
		if(_isAddedToRoot)
			core.notificator.sendEvent(event, fullName);
	}
	
	// ==============================================================================
	// IEntityChild
	// ==============================================================================
	override public function isEntity():Bool
	{
		return true; 
	}
	
	override function activate():Void
	{
		//TODO optimize
		//TODO should it call lost focus for children without current agenda?
		//TODO should it call onActivate before or after children activation?
		var focusedChildren = [];
		var curAgenda = getCurrentAgenda();
		for (child in _children)
		{
			if (child.isAddedToRoot())
			{
				child.activate();
				if (child.hasAgenda(curAgenda))
					focusedChildren.push(child);
			}
		}
		for (child in focusedChildren)
			child.setFocus(true);
	}
	
	override function deactivate():Void
	{
		//TODO optimize
		//TODO should it call lost focus for children without current agenda?
		//TODO should it call onDeactivate before or after children deactivation?
		for (child in _children)
			if (child.isFocused())
				child.setFocus(false);
				
		for (child in _children)
			if (child.isAddedToRoot())
				child.deactivate();
	}
	
	override function addToRoot():Void
	{
		Contract.ensures(_isAddedToRoot == true);
		
		_isAddedToRoot = true;

		if (parent.group != null && !isWrapped())
			addToGroup(parent.group);
		
		for (child in _children)
			child.addToRoot();
	}
	
	override function removeFromRoot():Void
	{
		Contract.ensures(_isAddedToRoot == false);
		
		for (child in _children)
			child.removeFromRoot();
		
		_isAddedToRoot = false;
		core.root.clearCachedChild(fullName);
			
		if (parent.group != null)
			removeFromGroup();
	}
	
	function addToGroup(p_group : IEntityGroup) : Void
	{
		Contract.requires(p_group != null && !(group != null && group != p_group));
		Contract.ensures(group == p_group && group.findEntity(name) == this);
		
		if (group == p_group)
			return;
		
		group = p_group;
		group.registerEntity(this);
	}

	function removeFromGroup() : Void
	{
		Contract.ensures(group == null);
		
		group.unregisterEntity(this);
		group = null;
	}

	// ==============================================================================
	// IAgendaManager
	// ==============================================================================
	public function getCurrentAgenda():String
	{
		return _activeAgendas[_activeAgendas.length - 1];
	}

	public function getActiveAgendas():Array<String>
	{
		return _activeAgendas.copy();
	}

	public function swap(p_agenda : Agenda) : Void
	{
		Contract.requires(Agenda.validate(p_agenda));
		Contract.ensures(getCurrentAgenda() == p_agenda && _activeAgendas.length == 2);
		
		_hideAll();
		show(p_agenda);
	}

	public function show(p_agenda : String) : Void
	{
		Contract.requires(Agenda.validate(p_agenda));
		Contract.ensures(getCurrentAgenda() == p_agenda); 
		
		if (p_agenda == getCurrentAgenda())
			return;
		_activeAgendas.remove(p_agenda);
		_activeAgendas.push(p_agenda);
		updateChildrenAgendaState();
	}

	public function hide(?p_agenda : String) : Void
	{
		Contract.requires(p_agenda == null || Agenda.validate(p_agenda));
		Contract.ensures(p_agenda != BaseAgenda.ALWAYS && getCurrentAgenda() != p_agenda);
		
		if (p_agenda == null)
			p_agenda = getCurrentAgenda();
		if (p_agenda == BaseAgenda.ALWAYS)
			return;
		_activeAgendas.remove(p_agenda);

		updateChildrenAgendaState();
	}

	public function hideAll():Void
	{
		Contract.ensures(getCurrentAgenda() == BaseAgenda.ALWAYS);
		
		_hideAll();
		updateChildrenAgendaState();
	}

	function _hideAll():Void
	{
		while (_activeAgendas.length > 1)
			_activeAgendas.pop();
	}

	// ==============================================================================
	// IPoolable
	// ==============================================================================
	public function setup(pool : IPool) : Void
	{
		_pool = pool;
		_isDestroyed = false;
	}

	public function clean() : Void
	{
		_isDestroyed = true;
	}

	public function clone() : ICloneable
	{
		return new Entity(core);
	}
}

