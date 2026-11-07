# Author: Nononever

module BattleSpeedControl

  SPEED_STAGES = [1.0, 1.5, 2.0, 3.0]

  DEFAULT_SPEED = 1

  SHOW_IN_OPTIONS = true

  TRIGGER_KEY = Input::ACTION

  @in_battle = false
  @battle_speed_multiplier = 1.0
  @last_real_time = nil
  @accelerated_time = 0

  def self.in_battle?
    @in_battle
  end

  def self.battle_speed_multiplier
    @battle_speed_multiplier
  end

  def self.start_battle
    @in_battle = true
    @battle_speed_multiplier = SPEED_STAGES[$PokemonSystem.battle_speed]
    @last_real_time = System.battle_speed_control_uptime || 0
    @accelerated_time = @last_real_time
  end

  def self.end_battle
    @in_battle = false
    @battle_speed_multiplier = 1.0
    @last_real_time = nil
  end

  def self.update_time
    return nil unless @in_battle && @last_real_time

    current_time = System.battle_speed_control_uptime
    return nil unless current_time

    @accelerated_time += [current_time - @last_real_time, 0].max * @battle_speed_multiplier
    @last_real_time = current_time
    return @accelerated_time
  end

  def self.update_trigger_key
    return unless @in_battle && TRIGGER_KEY

    if Input.trigger?(TRIGGER_KEY)

      current_index = $PokemonSystem.battle_speed
      next_index = (current_index + 1) % SPEED_STAGES.length
      $PokemonSystem.battle_speed = next_index

      update_time
      @battle_speed_multiplier = SPEED_STAGES[next_index]

      speed_text = "x#{SPEED_STAGES[next_index]}"
      pbMessage(_INTL("Battle speed changed to {1}", speed_text))
    end
  end
end

class PokemonSystem
  attr_accessor :battle_speed

  alias battle_speed_initialize initialize
  def initialize
    battle_speed_initialize
    @battle_speed = BattleSpeedControl::DEFAULT_SPEED
  end

  def battle_speed
    value = @battle_speed
    return value if value.is_a?(Integer) && value.between?(0, BattleSpeedControl::SPEED_STAGES.length - 1)
    BattleSpeedControl::DEFAULT_SPEED
  end
end

module System
  class << self
    alias battle_speed_control_uptime uptime unless method_defined?(:battle_speed_control_uptime)

    def uptime
      original_time = battle_speed_control_uptime
      return original_time unless original_time

      if BattleSpeedControl.in_battle?
        accelerated = BattleSpeedControl.update_time
        return accelerated if accelerated
      end

      original_time
    end
  end
end

EventHandlers.add(:on_start_battle, :battle_speed_start, proc {
  BattleSpeedControl.start_battle
})

EventHandlers.add(:on_end_battle, :battle_speed_end, proc {
  BattleSpeedControl.end_battle
})

class Battle::Scene
  alias battle_speed_control_frame_update pbFrameUpdate unless method_defined?(:battle_speed_control_frame_update)

  def pbFrameUpdate(*args, &block)
    result = battle_speed_control_frame_update(*args, &block)
    BattleSpeedControl.update_trigger_key if @battle
    result
  end
end

if BattleSpeedControl::SHOW_IN_OPTIONS
  MenuHandlers.add(:options_menu, :battle_speed, {
    "page"        => :gameplay,
    "name"        => _INTL("Battle Speed"),
    "order"       => 25,
    "type"        => defined?(EnumOption) ? EnumOption : :array,

    "parameters"  => BattleSpeedControl::SPEED_STAGES.map { |s| _INTL("x#{s}") },
    "description" => _INTL("Choose the speed for battles."),
    "get_proc"    => proc { next $PokemonSystem.battle_speed },
    "set_proc"    => proc { |value, scene|
      $PokemonSystem.battle_speed = value
    }
  })
end

speed_message = "v1.3.1 stages=#{BattleSpeedControl::SPEED_STAGES.join(',')} " \
                "default=x#{BattleSpeedControl::SPEED_STAGES[BattleSpeedControl::DEFAULT_SPEED]} " \
                "hotkey=#{BattleSpeedControl::TRIGGER_KEY ? 'on' : 'off'}"
if defined?(SCScripts) && SCScripts.respond_to?(:log)
  SCScripts.log(speed_message, :info, :battle)
else
  puts "[Battle Speed] #{speed_message}"
end
