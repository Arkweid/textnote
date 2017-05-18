# encoding: UTF-8


# ******************************************
# Светофор, page 90
# ******************************************

class TrafficLight
  class State
    def to_s
      name
    end

    def name
      self.class.name.split('::').last.downcase
    end

    def signal(traffic_light)
      traffic_light.turn_on_lamp(color.to_sym)
    end
  end

  class Stop < State
    def color; 'red'; end

    def next_state; Proceed.new; end
  end

  class Caution < State
    def color; 'yellow'; end

    def next_state; Stop.new; end

    def signal(traffic_light)
      super
      traffic_light.ring_warning_bell
    end
  end

  class Proceed < State
    def color; 'green'; end

    def next_state; Caution.new; end
  end

  def change_to(state)
    @state = State(state)
  end

  def next_state
    @state.next_state
  end

  def signal
    @state.signal(self)
  end

  private
# Этот метод дает нам возможность конвертировать входящие данные в нужные нам
# Совсем как Array("1"), к примеру
# Поэтому мы можем использовать такой синтаксис:
# light.change_to(:caution)
# Вместо ужасного
# light.change_to(TrafficLight::Caution.new)

  def State(state)
    case state
    when State then state
    else self.class.const_get(state.to_s.capitalize).new
    end
  end
end

light = TrafficLight.new
light.change_to(:caution)
light.signal
puts "Next state is: #{light.next_state}"

# => Turning on yellow lamp
# => Ring ring ring!
# => Next state is: stop
