package ai.bmn;


enum VariableKind {
    VKConstant;
    VKParameter;
    VKLocal;
}

enum BooleanExpression {
    BEUnaryOp(op:String, expr : BooleanExpression);
    BEBinaryOp(op:String, left : BooleanExpression, right : BooleanExpression);
    BEIdent(name:String);
    BELiteral(isTrue: Bool);
}

typedef Argument = {
    name:String,
    value:String
}

enum NumericExpression {
    NELiteral(value:String);
    NEUnaryOp(op:String, expr : NumericExpression);
    NEBinaryOp(op:String, left : NumericExpression, right : NumericExpression);
    NEIdent(name:String);
}

typedef Parameter = {
    name:String,
	expression:NumericExpression
}

typedef SubTask = {
    name:String,
    paramters:Array<Argument>
}

typedef Call = {
	name:String,
    arguments:Array<NumericExpression>
}

typedef Method = {name : String, condition : BooleanExpression, subtasks : Array<SubTask>};
typedef Effect = {state : String, expression : NumericExpression };

enum ExpressionType {
    ETFloat;
    ETInt;
    ETBool;
    ETUser(name:String);
}

typedef Decorator = {
    name : String
}

enum Condition {
    CIf( expr : NumericExpression );
    CWhile( expr : NumericExpression );
}

typedef SideCondition = {

}
enum BehaviourChild {
    BConditional(expr : NumericExpression);
    BChild(name : String, expr : SideCondition, decorators : Array<Decorator>);
}

enum StateKind {

}




//    preconditions : 


enum State {
    SSimple();
    SBehaviour(running: Node, succeeded : State, failed: State);
    SParent(children:Array<State>);
}

enum Behaviour {
    BAbstract(methods:Array<Node>);
    BSequence(actions:Array<Node>);
    BAll(actions:Array<Node>);
    BFirst(methods:Array<Node>);
    BInstance(name:String);
    BAction();
}

typedef Node = {
    name : String,
    behaviour : Behaviour,
    ?state: State,
    ?precondition: Condition
}

/*

enum TreeNodeKind {
    TNAbstract(name : String, solutions : Array<Declaration>);
    TNSequence(name :String, parallel : Bool, all : Bool, restart : Bool, continued : Bool, looped : Bool, children : Array<BehaviourChild>, sideCondition : SideCondition);
    TNAction(name : String, async : Bool, condition : BooleanExpression, effects : Array<Effect>,parameters:Array<Parameter>,calls:Array<Call>);
    TNReference( declaration : Declaration);
    TNState( state : StateKind );
}
*/

enum DeclarationKind {
    DStateMachine(root : Node);
    DBehaviourTree( root : Node);
    DVariable(kind : VariableKind, name : String, type : ExpressionType, value : NumericExpression);
    DAction();
    DParameter();

    //DAbstract(name : String, methods : Array<Method>);
    //DAbstract(name : String, solutions : Array<Declaration>);
    //DSequence(name :String, parallel : Bool, all : Bool, restart : Bool, continued : Bool, looped : Bool, children : Array<BehaviourChild>, sideCondition : SideCondition);
    //DOperator(name : String,  condition : BooleanExpression, effects : Array<Effect>, parameters:Array<Parameter>,calls:Array<Call>);
    //DAction(name : String, async : Bool, condition : BooleanExpression, effects : Array<Effect>,parameters:Array<Parameter>,calls:Array<Call>);
    //DState(name:String, children : Array<Declaration>);
}

typedef Declaration = {
    name : String,
    kind : DeclarationKind
}

typedef Tree = {
    root : Node,
    declarations : Array<Declaration>
}