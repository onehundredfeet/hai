package;


@:build(sm.macro.StateMachineBuilder.build("test/test.vdx", "ServerClientState", false, true, false))
class StateBuildTest {
    var a : Int = 0;
    var b : Int = 0;
    var c : Int = 0;

    @:enter(JOINING)
    @:enter(DISCONNECTING)
    function onBootState( s : sm.State) {
        a = 1;
        b = 2;
    }

    @:enter(JOINING)
    @:enter(DISCONNECTING)
    function onBoot() {
        a = 1;
        b = 2;
    }
    
    @:enterby(DISCONNECTING) 
    function onDisconnectedAll(s : sm.State, t : sm.Transition) {
        trace("I'm disconnected");
    }

    @:enterby(DISCONNECTING) 
    function onDisconnectedAllTrigger( t : sm.Transition) {
        trace("I'm disconnected");
    }

    @:enterby(DISCONNECTING) 
    function onDisconnectedAllState( s : sm.State) {
        trace("I'm disconnected");
    }

    @:enterby(DISCONNECTING) 
    function onDisconnectedAllNone() {
        trace("I'm disconnected");
    }


    @:enterby(DISCONNECTING, TIMEOUT) 
    function onDisconnectedByTimeout(s : sm.State,  t : sm.Transition) {
        trace("I'm disconnected");
    }

    @:enterfrom(DISCONNECTING, RECONNECTING) 
    function onDisconnectedFromReconnectAll(to : sm.State, from : sm.State) {
        trace("I'm disconnected");
    }

    @:enterfrom(DISCONNECTING, RECONNECTING) 
    function onDisconnectedFromReconnectNone() {
        trace("I'm disconnected");
    }

    @:exit(JOINING)
    function onLeave(s : sm.State) {
        a = 1;
        b = 2;
    }

}




class Test {

    public static function main() {
        var x = new StateBuildTest();
        
        trace('State: ${x.state} ${x.stateName}');
        x.fire(StateBuildTest.T_JOINED);
        trace('Is In HOLDING:  ${x.isIn( StateBuildTest.S_HOLDING)}');
        trace('Is In CONNECTED:  ${x.isIn( StateBuildTest.S_CONNECTED)}');
        trace('State: ${x.state} ${x.stateName}');
        x.fire(StateBuildTest.T_DISCONNECT);
        trace('Is In DISCONNECT_REQUESTED:  ${x.isIn( StateBuildTest.S_DISCONNECT_REQUESTED)}');
        trace('Is In DISCONNECTING:  ${x.isIn( StateBuildTest.S_DISCONNECTING)}');
        trace('State: ${x.state} ${x.stateName}');
        x.fire(StateBuildTest.T_REMOVE);
        trace('State: ${x.state} ${x.stateName}');
    }
}