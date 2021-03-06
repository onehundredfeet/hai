package test;

import ai.htn.Operator;



class ExampleHTN {
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
    public function tick() : TaskResult {
        var last = _concretePlan.length - 1;
        
        if (last < 0) return TaskResult.Completed;

        var status = TaskResult.Completed;
        while (last >= 0 && status == TaskResult.Completed) {
            switch(_concretePlan[last]) {
                case O_OPERATOR1: status = myOperator1();
                case O_OPERATOR2:status = myOperator2(0.);
                default: throw('Unknown operator ${_concretePlan[last]}');
            }
            if (status == TaskResult.Completed) {
                _concretePlan.pop();
                last--;

                if (last >= 0){
                    beginOperator( _concretePlan[last] );
                }
            }
        }
        return status;
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