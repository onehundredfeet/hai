package test;

import ai.common.TaskResult;
import ai.htn.Operator;
import ai.common.TaskResult;


class ExampleBT {
    static inline final PI : Float = 3;

    static inline final T_ABSTRACT1 = 0;
    static inline final T_ABSTRACT2 = 1;
    static inline final T_ABSTRACT3 = 2;
    static inline final O_OPERATOR1 = 0;
    static inline final O_OPERATOR2 = 1;
    
    public var DASH_RANGE : Float;
    public var enemyRange : Float;
    public var enemyVisible : Bool;

    static inline final VAR_DASH_RANGE = 0;
    static inline final VAR_enemyRange = 1;
    static inline final VAR_enemyVisible = 2;
    
    var _effectStackValue = new Array<Dynamic>();

    public function new() {

    }

    var _concretePlan : Array<Int> = [];

    var current_SEQ_seq0 = 0;
    var current_SEL_sel0 = 0;

    function reset_SEQ_seq0() {
        SEQ_seq0_current = 0;
    }

    function ACT_stepA() : TaskResult {
        return TaskResult.Success;
    }

    function ACT_stepB() : TaskResult {
        return TaskResult.Success;
    }

    function ACT_stepC() : TaskResult {
        return TaskResult.Success;
    }

    function ACT_stepD() : TaskResult {
        return TaskResult.Success;
    }
    var state_PAR_par0_action_stepD : TaskResult;
    var state_PAR_par0_action_stepE : TaskResult;
    
    var state_PAR_par0 : TaskResult;
    function tick_PAR_par0() {
        if (state_PAR_par0_action_stepD == TaskResult.Running) state_PAR_par0_action_stepD = ACT_stepD();
        if (state_PAR_par0_action_stepE == TaskResult.Running) state_PAR_par0_action_stepE = ACT_stepE();

        if ( state_PAR_par0_action_stepD == TaskResult.Failed || state_PAR_par0_action_stepE == TaskResult.Failed) return TaskResult.Failed;
        if ( state_PAR_par0_action_stepD == TaskResult.Completed && state_PAR_par0_action_stepE == TaskResult.Completed) return TaskResult.Completed;
        
        return TaskResult.Running;
    }

    function tick_FIRST_sel0() {
        while (current_SEL_sel0 < 3 ) {
            var res = switch(current_SEQ_seq0) {
                case 0: ACT_stepA();
                case 1: ACT_stepB();
                default: TaskResult.Success;
            }    
            switch(res) {
                case Completed:return TaskResult.Success;
                case Failed: current_SEL_sel0++;
                case Running:return TaskResult.Running;
            }
        }

        return TaskResult.Failed;
    }

    inline function invResult( res : TaskResult ) {
        return switch(res) {
            case TaskResult.Failed: TaskResult.Completed;
            case TaskResult.Completed : TaskResult.Failed;
            default: res;
        }
    }

    function tick_SEQ_seq0() : TaskResult {
        while (current_SEQ_seq0 < 3 ) {
            var res = switch(current_SEQ_seq0) {
                case 0: ACT_stepA();
                case 1: tick_FIRST_sel0();
                case 2: ACT_StepC();
                default: TaskResult.Success;
            }    
            switch(res) {
                case Completed:current_SEQ_seq0++;
                case Failed:return TaskResult.Failed;
                case Running:return TaskResult.Running;
            }
        }

        return TaskResult.Success;
    }

    public function tick() : TaskResult {
        return SEQ_seq0_tick();
    }

    /*
    public function plan(task : Int, maxDepth : Int) {
        _concretePlan.resize(0);
        _effectStackValue.resize(0);

        switch(task) {
            case T_ABSTRACT1:  return resolve_abstract1(maxDepth);
            case T_ABSTRACT2:  return resolve_abstract2(maxDepth);
            case T_ABSTRACT3:  return resolve_abstract2(maxDepth);
           
        }
        return BranchState.Failed;
    }

    inline function unwind( concreteLength : Int) {
        if (concreteLength < _concretePlan.length) {
            var x = _concretePlan.pop();
            switch(x) {
                case O_OPERATOR1:
                    enemyRange = _effectStackValue.pop();
                case O_OPERATOR2:
                    enemyRange = _effectStackValue.pop();
                default:
            }
        }
    }

    function concreteSuccess(task : Int) {
        _concretePlan.push(task);
        return BranchState.Success;
    }
*/
    inline function setEnemyRange( v : Float ) {
        _effectStackValue.push(enemyRange);
        enemyRange = v;
    }

    function operator_OPERATOR1( ) : BranchState {
        if (enemyVisible) {
            setEnemyRange(enemyRange + 1);
            myOperator1();
            return concreteSuccess(O_OPERATOR1);
        }

        return BranchState.Failed;
    }

    function operator_OPERATOR2( val_f : Float) : BranchState {
        if (enemyVisible && enemyVisible) {
            setEnemyRange(enemyRange + val_f);
            myOperator2(val_f);
            return concreteSuccess(O_OPERATOR2);
        }

        return BranchState.Failed;
    }

    function resolve_abstract1( depth : Int ) {
        var next_depth = depth - 1;
        if (next_depth <= 0) return BranchState.Incomplete;

        var concrete_progress = _concretePlan.length;

        if (enemyRange > DASH_RANGE)  { // Method 1
            if (resolve_abstract2( next_depth ) == BranchState.Success && 
                resolve_abstract2( next_depth ) == BranchState.Success) return BranchState.Success;
        } 
        
        if (true) {
            if (resolve_abstract3(next_depth ) == BranchState.Success && 
                operator_OPERATOR1() == BranchState.Success) return BranchState.Success;
        }

        unwind(concrete_progress);
        return BranchState.Failed;
    }

    function resolve_abstract2( depth : Int ) {
        var next_depth = depth - 1;
        if (next_depth < 0) return BranchState.Incomplete;

        var concrete_progress = _concretePlan.length;

        if (enemyRange > DASH_RANGE)  { // Method 1
            if (operator_OPERATOR1() == BranchState.Success && 
                operator_OPERATOR2(  enemyRange ) == BranchState.Success) return BranchState.Success;
        }
        unwind(concrete_progress);
        return BranchState.Failed;
    }

    function resolve_abstract3( depth : Int ) {
        var next_depth = depth - 1;
        if (next_depth < 0) return BranchState.Incomplete;

        var concrete_progress = _concretePlan.length;

        if (enemyRange > DASH_RANGE)  { // Method 1
            if (operator_OPERATOR1() == BranchState.Success && 
                operator_OPERATOR2(  enemyRange ) == BranchState.Success) return BranchState.Success;
        }
        unwind(concrete_progress);
        return BranchState.Failed;
    }

    public function execute() {
        _concretePlan.reverse();
        var last = _concretePlan.length - 1;
        
        if (last < 0) return ;
        beginOperator( _concretePlan[last] );
    }

    function beginOperator(op : Int) {
        switch(op) {
            case O_OPERATOR1: myOperator1_start();
            case O_OPERATOR2: myOperator2_start(0.);
            default: throw('Unknown operator ${op}');
        }
    }
  

    // User class
    @:tick(O_OPERATOR1)
    function myOperator1() : TaskResult{
        return TaskResult.Running;
    }

    @:tick(O_OPERATOR2)
    function myOperator2(parameter : Float) : TaskResult {
        return TaskResult.Running;
    }

    @:begin(O_OPERATOR1)
    function myOperator1_start() {

    }

    @:begin(O_OPERATOR2)
    function myOperator2_start(parameter : Float)  {
    }
}

#if false


const PI : Float = 3
param DASH_RANGE : Float

var enemyRange : Float
var enemyVisible : Bool

abstract abstract1
    method_name : enemyRange > DASH_RANGE
        abstract2
        abstract2
    method_name : true
        abstract3
        operator_1

abstract abstract2
    method_name : enemyRange > DASH_RANGE
        operator_1
        operator_2( parameter : enemyRange )

operator operator_1 : enemyVisible
    enemyRange = enemyRange + 1

operator operator_2(parameter : Float) : enemyVisible & enemyVisible
    enemyRange = enemyRange + parameter

/*

    /*
    function resolveAbstract(task : Int, depth : Int) : BranchState{
        var concrete_progress = _concretePlan.length;
        var next_depth = depth - 1;
        if (depth <= 0) return BranchState.Incomplete;

        switch(task) {
            case T_ABSTRACT1: 
                if (enemyRange > DASH_RANGE)  { // Method 1
                    if (resolveAbstract(T_ABSTRACT2, next_depth ) == BranchState.Success && 
                        resolveAbstract(T_ABSTRACT2, next_depth ) == BranchState.Success) return BranchState.Success;
                } 
                
                if (true) {
                    if (resolveAbstract(T_ABSTRACT3, next_depth ) == BranchState.Success && 
                        operator_OPERATOR1() == BranchState.Success) return BranchState.Success;
                }

                unwind(concrete_progress);
                return BranchState.Failed;
            case T_ABSTRACT2: 
                if (enemyRange > DASH_RANGE)  { // Method 1
                    if (operator_OPERATOR1() == BranchState.Success && 
                        operator_OPERATOR2(  enemyRange ) == BranchState.Success) return BranchState.Success;
                }
                unwind(concrete_progress);
                return BranchState.Failed;
            default:throw("unknown abstract");
        }

        return BranchState.Failed;
    }
   
//var agentStatemachine : MyStateMachine

#var agentStatemachineEmbed : StateMachine
#    A(a) -> B,
#    A(b) -> C,
#    B(b) -> C

#var agentStatemachineEmbedHierarchical : StateMachine
#    A(a) -> B,
#    A(b) -> C,
#    B(b) -> C,
#    B(entry) -> B.default,
#    B.default(c) -> B.next
*/
#end