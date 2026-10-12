/// Expression tree produced by MathParser and consumed by MathEvaluator.
indirect enum MathExpr {
    case number(Double)
    case variable(String)
    case negate(MathExpr)
    case binary(MathBinaryOp, MathExpr, MathExpr)
    case call(String, [MathExpr])
}

enum MathBinaryOp {
    case add, subtract, multiply, divide, power
}
