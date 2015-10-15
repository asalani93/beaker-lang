require 'rltk/ast'

module FormulaFields
  class Expression < RLTK::ASTNode
    def evaluate(_); end

    def to_s; end
  end

  class Binary < Expression
    child :left, Expression
    child :right, Expression

    def evaluate(env)
      l = @left.evaluate(env)
      r = @right.evaluate(env)
      [l, r]
    end
  end

  class Add < Binary
    def evaluate(env)
      l, r = super(env)

      if l.type == :text or r.type == :text
        TextType.concatenate(l, r)
      elsif l.type == :number and r.type == :number
        NumberType.arithmetic(:add, l, r)
      else
        fail ArgumentTypeError.new('+', [:number, :number], [l.type, r.type])
      end
    end

    def to_s
      "(+ #{@left} #{@right})"
    end
  end

  class Sub < Binary
    def evaluate(env)
      l, r = super(env)

      if l.type == :number and r.type == :number
        NumberType.arithmetic(:sub, l, r)
      else
        fail ArgumentTypeError.new('-', [:number, :number], [l.type, r.type])
      end
    end

    def to_s
      "(- #{@left} #{@right})"
    end
  end

  class Mul < Binary
    def evaluate(env)
      l, r = super(env)

      if l.type == :number and r.type == :number
        NumberType.arithmetic(:mul, l, r)
      elsif l.type == :text and r.type == :number
        TextType.repeat(l, r)
      elsif l.type == :number and r.type == :text
        TextType.repeat(r, l)
      else
        fail ArgumentTypeError.new('*', [:number, :number], [l.type, r.type])
      end
    end

    def to_s
      "(* #{@left} #{@right})"
    end
  end

  class Div < Binary
    def evaluate(env)
      l, r = super(env)

      if l.type == :number and r.type == :number
        NumberType.arithmetic(:div, l, r)
      else
        fail ArgumentTypeError.new('/', [:number, :number], [l.type, r.type])
      end
    end

    def to_s
      "(/ #{@left} #{@right})"
    end
  end

  class Mod < Binary
    def evaluate(env)
      l, r = super(env)

      if l.type == :number and r.type == :number
        NumberType.arithmetic(:mod, l, r)
      else
        fail ArgumentTypeError.new('%', [:number, :number], [l.type, r.type])
      end
    end

    def to_s
      "(% #{@left} #{@right})"
    end
  end

  class Pow < Binary
    def evaluate(env)
      l, r = super(env)

      if l.type == :number and r.type == :number
        NumberType.arithmetic(:pow, l, r)
      else
        fail ArgumentTypeError.new('^', [:number, :number], [l.type, r.type])
      end
    end

    def to_s
      "(^ #{@left} #{@right})"
    end
  end

  class And < Binary
    def evaluate(env)
      l, r = super(env)
      if l.type == :bool and r.type == :bool
        BooleanType.new(l.get && r.get)
      else
        fail ArgumentTypeError.new('&&', [:bool, :bool], [l.type, r.type])
      end
    end

    def to_s
      "(and #{@left} #{@right})"
    end
  end

  class Or < Binary
    def evaluate(env)
      l, r = super(env)
      if l.type == :bool and r.type == :bool
        BooleanType.new(l.get || r.get)
      else
        fail ArgumentTypeError.new('||', [:bool, :bool], [l.type, r.type])
      end
    end

    def to_s
      "(or #{@left} #{@right})"
    end
  end

  class Equality < Binary
    def evaluate(env)
      l, r = super(env)
      if l.type == r.type and l.can_eq?
        BooleanType.new(l.eq(r, @eq_sym))
      else
        fail ArgumentTypeError.new(@eq_name, [:eq, :eq], [l.type, r.type])
      end
    end
  end

  class Equal < Equality
    def initialize(l, r)
      super(l, r)
      @eq_name = '=='
      @eq_sym = :eq
    end

    def to_s
      "(eq? #{@left} #{@right})"
    end
  end

  class NotEqual < Equality
    def initialize(l, r)
      super(l, r)
      @eq_name = '!='
      @eq_sym = :ne
    end

    def to_s
      "(ne? #{@left} #{@right})"
    end
  end

  class Ordering < Binary
    def evaluate(env)
      l, r = super(env)
      if l.type == r.type and l.can_ord?
        BooleanType.new(l.ord(r, @comp_sym))
      else
        fail ArgumentTypeError.new(@comp_name, [:ord, :ord], [l.type, r.type])
      end
    end
  end

  class LessThan < Ordering
    def initialize(l, r)
      super(l, r)
      @comp_name = '<'
      @comp_sym = :lt
    end

    def to_s
      "(< #{@left} #{@right})"
    end
  end

  class LessThanEqual < Ordering
    def initialize(l, r)
      super(l, r)
      @comp_name = '<='
      @comp_sym = :le
    end

    def to_s
      "(<= #{@left} #{@right})"
    end
  end

  class GreaterThan < Ordering
    def initialize(l, r)
      super(l, r)
      @comp_name = '>'
      @comp_sym = :gt
    end

    def to_s
      "(> #{@left} #{@right})"
    end
  end

  class GreaterThanEqual < Ordering
    def initialize(l, r)
      super(l, r)
      @comp_name = '>='
      @comp_sym = :ge
    end

    def to_s
      "(>= #{@left} #{@right})"
    end
  end

  class Not < Expression
    child :expr, Expression

    def evaluate(env)
      x = @expr.evaluate(env)
      if x.type == :bool
        BooleanType.new(!x.get)
      else
        fail ArgumentTypeError.new('!', [:bool], [x.type])
      end
    end

    def to_s
      "(not #{@expr})"
    end
  end

  class Resolvable < Expression; end

  class Name < Resolvable
    value :name, String

    def evaluate(env)
      x = env.lookup(@name)
      if x.nil?
        fail NameResolutionError.new(self)
      else
        x
      end
    end

    def to_s
      "#{@name}"
    end
  end

  class Resolve < Resolvable
    child :rest, Expression
    child :name, Name

    def evaluate(env)
      scope = @rest.evaluate(env)
      x = env.lookup(@name.name, scope)
      if x.nil?
        fail NameResolutionError.new(@name)
      elsif x.is_a? MethodType
        x.parent(scope)
        x
      else
        x
      end
    end

    def to_s
      "#{@rest}:#{@name}"
    end
  end

  class Call < Expression
    child :name, Expression
    child :args, [Expression]

    def evaluate(env)
      n = @name.evaluate(env)
      a = @args.map do |x|
        x.evaluate(env)
      end

      if n.type == :function
        n.call(env, a)
      else
        fail NotCallableError.new(@name, n.type)
      end
    end

    def to_s
      if args.length == 0
        "(#{@name})"
      else
        args = @args.map(&:to_s).join(' ')
        "(#{@name} #{args})"
      end
    end
  end

  class UnresolvedName < Expression
    value :name, String
    child :next, UnresolvedName

    def evaluate(_ = nil)
      if @next.nil?
        [@name]
      else
        @next.evaluate + [@name]
      end
    end

    def to_s
      evaluate.join ':'
    end
  end

  class Assign < Expression
    child :left, [UnresolvedName]
    child :right, Expression

    def evaluate(env)
      r = @right.evaluate(env)
      @left.each do |left|
        l = left.evaluate(env)
        env.assign(l, r)
      end
      r
    end

    def to_s
      if @left.length > 1
        "(let (#{@left.join ', '}) #{@right})"
      else
        "(let #{@left[0]} #{@right})"
      end
    end
  end

  class NumberLiteral < Expression
    value :value, Float

    def evaluate(_)
      NumberType.new(@value)
    end

    def to_s
      @value.to_s
    end
  end

  class StringLiteral < Expression
    value :value, String

    def evaluate(_)
      TextType.new(@value[1, @value.length - 2])
    end

    def to_s
      "\"#{@value[1, @value.length - 2]}\""
    end
  end
end
