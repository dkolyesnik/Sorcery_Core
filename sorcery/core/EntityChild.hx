package sorcery.core;
import sorcery.core.BaseAgenda;
import sorcery.core.CoreNames;
import sorcery.core.abstracts.Agenda;
import sorcery.core.interfaces.IEntity;
import haxecontracts.Contract;
import haxecontracts.HaxeContracts;

import sorcery.core.interfaces.ICore;
import sorcery.core.interfaces.IEntityChild;

/**
 * ...
 * @author Dmitriy Kolyesnik
 */
class EntityChild implements IEntityChild implements HaxeContracts
{
	//var _isActivatedByParent = false;
	var _isAddedToRoot = false;
	var _isFocused = false;
	var _agendas:Map<String, Bool>;
	var _useByAgendaCount = 0;
	
	private function new(p_core:ICore)
	{
		core = p_core;
	}

	/* INTERFACE bgcore.interfaces.IEntityChild */
	public var core(get, null):ICore;
	public var parent(get, null):IEntity;
	public var name(get, null):String;

	// ==============================================================================
	// GETTERS & SETTERS
	// ==============================================================================
	function get_core():ICore
	{
		return core;
	}

	function get_parent():IEntity
	{
		return parent;
	}

	function get_name():String
	{
		return name;
	}

	// ==============================================================================
	// METHODS
	// ==============================================================================
	public function isEntity():Bool
	{
		return false;
	}

	public function isActivatedByParent():Bool
	{
		return _isActivatedByParent;
	}

	public function isFocused():Bool
	{
		return _isFocused;
	}

	public function isAddedToRoot() : Bool
	{
		return _isAddedToRoot;
	}

	public function setName(p_name:String):IEntityChild
	{
		Contract.requires(p_name != CoreNames.ROOT && p_name != "");
		Contract.requires( parent == null || name == p_name);
		
		if (parent == null)
		{
			name = p_name;
		}
		
		return this;
	}

	public function destroy():Void
	{

	}
	
	

	public function hasAgenda(p_agenda:String):Bool
	{
		Contract.requires(Agenda.validate(p_agenda));
		
		if (_agendas == null)
			return p_agenda == BaseAgenda.ALWAYS;

		return _agendas.exists(p_agenda);
	}

	public function addAgenda(p_agenda:String):Void
	{
		Contract.requires(Agenda.validate(p_agenda));
		Contract.ensures(_agendas.exists(p_agenda));
		
		if (_agendas == null)
			_agendas = new Map();

		if (!_agendas.exists(p_agenda))
		{
			_agendas[p_agenda] = true;
			if (parent != null)
				parent.updateChildrenAgendaState();
		}
	}

	public function removeAgenda(p_agenda:String):Void
	{
		Contract.requires(Agenda.validate(p_agenda));
		Contract.ensures(_agendas == null || !_agendas.exists(p_agenda));
		
		if (_agendas != null && _agendas.remove(p_agenda))
		{
			if (parent != null)
				parent.updateChildrenAgendaState();
		}
	}
	
	function getUseByAgendaCount():Int
	{
		return _useByAgendaCount;
	}
	
	/**
	 * called when agenda is activated, check if it need to increase use count
	 * @return true if has agenda and use count is increased
	 */
	function activateByAgenda(p_agenda:Agenda):Bool
	{
		Contract.requires(Agenda.validate(p_agenda));
		
		if (_agendas.exists(p_agenda))
		{
			_useByAgendaCount++;
			return true;
		}
		else
			return false;
	}
	
	/**
	 * called when agenda is deactivated, decrease use count if has this agenda
	 * @return true if use count is decreased to 0 and we need to deactivate child
	 */
	function deactivateByAgends(p_agenda:Agenda):Bool
	{
		Contract.requires(Agenda.validate(p_agenda));
		Contract.ensures(_useByAgendaCount >= 0);
		
		if (_agendas.exists(p_agenda))
		{
			_useByAgendaCount--;
			return _useByAgendaCount == 0;
		}	
		else
			return false;
	}
	
	function activate():Void
	{
		
	}
	function deactivate():Void
	{
		
	}
	
	function addToParent(p_parent:IEntity):Void
	{
		Contract.requires(p_parent != null);
		
		parent = p_parent;
	}
	function removeFromParent():Void
	{
		Contract.ensures(parent == null);
		
		_useByAgendaCount = 0;
		parent = null;
	}
	
	function addToRoot():Void
	{
		_isAddedToRoot = true;
	}
	
	function removeFromRoot():Void
	{
		_isAddedToRoot = false;
	}
	
	
	//function onActivatedByParent():Void
	//{
		//_isActivatedByParent = true;
	//}
	//
	//function onDeactivatedByParent():Void
	//{
		//_isActivatedByParent = false;
	//}


	function setFocus(focus:Bool):Void
	{
		Contract.ensures(focus == _isFocused);
		
		//if (_isFocused == focus)
			//return;
		_isFocused = focus;
		//if (_isFocused)
			//onFocus();
		//else
			//onLostFocus();
	}

	//function onFocus():Void
	//{
//
	//}
//
	//function onLostFocus():Void
	//{
//
	//}

}