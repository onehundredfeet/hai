package ai.tools;


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

enum BehaviourChild {
    BConditional(expr : NumericExpression);
    BChild(name : String, expr : NumericExpression, decorators : Array<Decorator>);
}

enum Declaration {
    DVariable( kind : VariableKind,name : String, type : ExpressionType, value : NumericExpression );
    DAbstract(name : String, methods : Array<Method>);
    DOperator(name : String,  condition : BooleanExpression, effects : Array<Effect>, parameters:Array<Parameter>,calls:Array<Call>);
    DSequence(name :String, parallel : Bool, all : Bool, restart : Bool, continued : Bool, looped : Bool, children : Array<BehaviourChild>);
}
