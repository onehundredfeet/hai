package;


// enum abstract EExternalState(Int) {
//     var S_ROOT = 0;
//     var S_HOLDING = 1;

//     private inline function new(value : Int) {
//         this.value = value;
//     }
// }

// enum abstract EExternalTransition(Int) {
//     var T_ROOT = 0;
//     var T_HOLDING = 1;

//     private inline function new(value : Int) {
//         this.value = value;
//     }
// }

// class ExternalState {
//     var _state : EExternalState;
//     var _timer0 : Float;
//     var _transitionQueue : Array<EExternalTransition>;
// }



// @:build(ai.sm.macro.ExternalSM.buildState("test/examples.vdx", "sm"))
// class ExternalState {
    
// }

@:build(ai.sm.macro.ExternalSM.buildMachine("test/examples.vdx", "sm"))
@:sm_print
@:sm_tick
class ExternalStateMachine {
    // public function make() {
    //     return new ExternalState(0);
    // }

    var a : Int = 0;
    var b : Int = 0;
    var c : Int = 0;

    @:while(HOLDING)
    @:after(0.1)
    function doTime( self:ExternalStateMachineState) {
    }

    @:enter(DISCONNECT_REQUESTED)
    @:enter(DISCONNECTING)
    function onBootState( self:ExternalStateMachineState, s : EExternalStateMachineState) {
        a = 1;
        b = 2;
    }

    @:enterby(DISCONNECTING) 
    function onDisconnectedAll(self:ExternalStateMachineState,s : EExternalStateMachineState, t : EExternalStateMachineTransition) {
        trace('onDisconnectedAll - I\'m disconnected ${s}');
    }

    @:enterby(DISCONNECTING) 
    function onDisconnectedAllTrigger( self:ExternalStateMachineState, t : EExternalStateMachineTransition) {
        trace("onDisconnectedAllTrigger - I'm disconnected");
    }

    @:enterby(DISCONNECTING) 
    function onDisconnectedAllState( self:ExternalStateMachineState, s : EExternalStateMachineState) {
        trace("onDisconnectedAllState - I'm disconnected");
    }
}

/*
@:sm_print
@:build(ai.sm.macro.StateMachineBuilder.build("test/examples.vdx", "sm", false, false))
class StateBuildTest {
    public function new() {
        __state_init();
    }

    var a : Int = 0;
    var b : Int = 0;
    var c : Int = 0;

   

    @:enter(JOINING)
    @:enter(DISCONNECTING)
    function onBoot() {
        a = 1;
        b = 2;
    }
    
    @:enterby(DISCONNECTING) 
    function onDisconnectedAll(s : ai.sm.State, t : ai.sm.Transition) {
        trace('onDisconnectedAll - I\'m disconnected ${s}');
    }

    @:enterby(DISCONNECTING) 
    function onDisconnectedAllTrigger( t : ai.sm.Transition) {
        trace("onDisconnectedAllTrigger - I'm disconnected");
    }

    @:enterby(DISCONNECTING) 
    function onDisconnectedAllState( s : ai.sm.State) {
        trace("onDisconnectedAllState - I'm disconnected");
    }

    @:enterby(DISCONNECTING) 
    function onDisconnectedAllNone() {
        trace("onDisconnectedAllNone - I'm disconnected");
    }


    @:enterby(DISCONNECTING, REMOVE) 
    function onDisconnectedByREMOVE(s : ai.sm.State,  t : ai.sm.Transition) {
        trace("onDisconnectedByREMOVE  - I'm disconnected");
    }

    @:enterfrom(DISCONNECTING, RECONNECTING) 
    function onDisconnectedFromReconnectAll(to : ai.sm.State, from : ai.sm.State) {
        trace("onDisconnectedFromReconnectAll - I'm disconnected");
    }

    @:enterfrom(DISCONNECTING, RECONNECTING) 
    function onDisconnectedFromReconnectNone() {
        trace("onDisconnectedFromReconnectNone - I'm disconnected");
    }

    @:exit(ROOT)
    function onLeave(s : ai.sm.State) {
        trace('Leaving');
        a = 1;
        b = 2;
    }

}


*/

class TestESM {

    public static function main() {
        var m = new ExternalStateMachine();
        var s = new ExternalStateMachineState();
        trace('State: ${s.state}');

        s.queue(EExternalStateMachineTransition.JOINED);
        m.process(s);
        trace('State: ${s.state}');

        // var x = new StateBuildTest();
        
        // trace('State: ${x.state} ${x.stateName}');
        // trace('Firing JOINED');
        // x.fire(StateBuildTest.T_JOINED);
        // trace('Is In HOLDING:  ${x.isIn( StateBuildTest.S_HOLDING)}');
        // trace('Is In ROOT:  ${x.isIn( StateBuildTest.S_ROOT)}');
        // trace('Is In CONNECTED:  ${x.isIn( StateBuildTest.S_CONNECTED)}');
        // trace('State: ${x.state} ${x.stateName}');
        // trace('Firing DISCONNECT');
        // x.fire(StateBuildTest.T_DISCONNECT);
        // trace('Is In DISCONNECT_REQUESTED:  ${x.isIn( StateBuildTest.S_DISCONNECT_REQUESTED)}');
        // trace('Is In DISCONNECTING:  ${x.isIn( StateBuildTest.S_DISCONNECTING)}');
        // trace('Is In ROOT:  ${x.isIn( StateBuildTest.S_ROOT)}');
        // trace('State: ${x.state} ${x.stateName}');
        // trace('Firing REMOVE');
        // x.fire(StateBuildTest.T_REMOVE);
        // trace('State: ${x.state} ${x.stateName}');
        // trace('Is In ROOT:  ${x.isIn( StateBuildTest.S_ROOT)}');
    }
}