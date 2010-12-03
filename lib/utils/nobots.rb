module Utils
  
  class BotVerifier
    def initialize(seed=nil)
      3.times { Kernel.srand }
      @seed = Kernel.srand
      @seed = seed if seed
      gen_math
    end
    
    def gen_math
      2.times { Kernel.srand(@seed) }
      @optree = ['50.0']
      ops = %w{+ - / * %}
      5.times do
        @optree.push ops[(Kernel.rand*ops.size).to_i]
        @optree.push (Kernel.rand * 1000).to_i.to_f.to_s
      end
      @math_ops = @optree.join(" ")
      @math_result = eval(@math_ops)
    end
    
    def gen_fake_math
      optree = ['50.0']
      ops = %w{+ - / * %}
      5.times do
        optree.push ops[(Kernel.rand*ops.size).to_i]
        optree.push (Kernel.rand * 10).to_i.to_f.to_s
      end
      optree.join(" ")
    end
    
    def js
      names = %w{a b c d e f g}
      names = names.sort_by { rand }
      
      ashash = {}
      ashash[names[0]] = @math_ops
      ashash[names[1]] = "'#{names[0]}/2.0 + screen.height'"
      ashash[names[2]] = "'0.5*#{names[0]} - screen.height'"
      ashash[names[3]] = gen_fake_math
      ashash[names[4]] = "'0.5*#{names[3]} + screen.width'"
      ashash[names[5]] = "5 * 1 / #{names[0]}"
      ashash[names[6]] = "2 % #{names[5]}"
      
      src = "document.observe('dom:loaded', function() {\n"
      ashash.keys.sort.each do |name|
        val = ashash[name]
        src += "var #{name} = #{val};\n"
      end
      src += "$('bot_verify').value = eval(#{names[1]}) + eval(#{names[2]});\n"
      src += "$('bot_seed').value = '#{"%x" % @seed}';\n"
      src += "});\n"
      src
    end
    
    def verify(req)
      (req.query['bot_verify'].to_f - @math_result.to_f).abs < 0.1
    end
  end
  
end