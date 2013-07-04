
class Position

  attr_reader :x, :y, :z

  def initialize(args)
    @x = args.fetch(:x)
    @y = args.fetch(:y)
    @z = args.fetch(:z, 0)
  end

  def ==(other_position)
    x == other_position.x && y == other_position.y
  end

  # use x,y,z or dx,dy,dz or any combination thereof
  def move(args)
    nx = args.fetch(:x, args.fetch(:dx, 0) + x)
    ny = args.fetch(:y, args.fetch(:dy, 0) + y)
    nz = args.fetch(:z, args.fetch(:dz, 0) + z)
    self.class.new(x: nx, y: ny, z: nz)
  end

  def each_position_within_radius(r)
    (-r..r).each do |dx|
      (-r..r).each do |dy|
        yield move(dx: dx, dy: dy)
      end
    end
  end

  def distance_to(other_position)
    dx = other_position.x - x
    dy = other_position.y - x
    Math.sqrt( dx**2 + dy**2 )
  end

  def to_s
    "(#{x}, #{y}) depth #{z}"
  end

end

class Unit

  attr_accessor :position

  def initialize(args = {})
    @position = args.fetch(:position)
    @alive = true
  end

  def move(args)
    position.move(args)
  end

  def alive?
    @alive
  end

  def kill
    @alive = false
  end

end

class Ship < Unit

  def symbol; 'S'; end

  def play_turn

  end

end

class Monster < Unit

  def symbol; 'M'; end

end

class Mine < Unit

  def symbol; '$'; end

end

class Headquarters < Unit

  def symbol; 'H'; end

end

class Player < Unit

  attr_reader :power, :fuel, :damage
  attr_accessor :torpedos, :missles, :crew

  def initialize(args)
    @power = args.fetch(:power, 6000)
    @fuel = args.fetch(:fuel, 2500)
    @torpedos = args.fetch(:torpedos, 10)
    @missles = args.fetch(:missles, 3)
    @crew = args.fetch(:crew, 30)
    @damage = Hash[ systems.zip( [0.0] * systems.size ) ]
    super
  end

  def systems
    %i{engines sonar torpedos missles maneuvering status headquarters sabotage converter}
  end

  def system_manning
    Hash[systems.zip([9, 6, 11, 24, 13, 4, 0, 11, 6])]
  end

  def system_manned?(system) 
    crew >= system_manning.fetch(system)
  end

  def system_ok?(system)
    damage.fetch(system).round >= 0
  end

  def damage_random_system(&block)
    @damage[systems.sample] -= block.call
  end

  def repair_random_system
    depth_factor = (50...2000).cover?(position.z) ? 1 : 0
    dmg = damage.fetch(systems.sample)
    damage_factor = dmg > 3 ? 0 : 1
    @damage[systems.sample] += rand * (2 + rand * 2) * depth_factor * damage_factor 
  end

  def symbol; 'X'; end

  def spend_power(amount)
    if reactor_overload?(amount)
      puts "Atomic pile goes supercritical!!! Headquarters"
      puts "will warn all subs to stay from radioactive area!!!"
      throw :game
    end
    @power -= amount.round
    if reactor_dead?
      puts "Atomic pile has gone dead!!! Sub sinks, crew suffocates"
      throw :game
    end
  end

  def spend_fuel(amount)
    @fuel -= amount
  end

  def add_power(amount)
    @power += amount.round
  end

  def add_fuel(amount)
    @fuel += amount.round
  end

  def fatally_damaged?
    vitals = %i{engines sonar torpedos missles maneuvering status sabotage converter}
    vitals.all? { |v| damage.fetch(v).round < 0 }
  end

  def at_missle_depth?
    (51..2000).cover?(depth)
  end

  def depth
    position.z
  end

  private

  def reactor_dead?
    power <= 0
  end

  def reactor_overload?(amount)
    amount > 1000 && rand >= 0.43
  end

end

class World

  attr_reader :max_x, :max_y, :map, :units, :position_class

  def initialize(args = {})
    @max_x = args.fetch(:max_x, 19)
    @max_y = args.fetch(:max_y, 19)
    @map = Array.new(@max_x + 1) { |i| Array.new(@max_y + 1, 0) }
    @position_class = args.fetch(:position_class, Position)
    @units = []
    setup_map
  end

  def setup_map
    island = island_data
    (6..12).each do |x|
      (6..11).each do |y|
        @map[x][y] = island.shift
      end
    end
  end

  def island_data
    [0, 1, 1, 1, 0, 0, 0, 1, 1, 1, 1, 0, 1, 1, 1, 0, 1, 1, 1, 1, 0, 0, 0, 1,
      1, 1, 0, 0, 1, 1, 0, 1, 1, 0, 1, 0, 0, 0, 1, 0, 0, 0]
  end

  def random_unused_location
    begin
      x = rand(0..max_x)
      y = rand(0..max_y)
      pos = position_class.new(x: x, y: y, world: self)
    end while collision?(pos)
    pos
  end

  def collision?(position)
    units.any? { |u| u.position == position } || (@map[position.x][position.y] != 0)
  end

  def valid_position?(position)
    (0..max_x).cover?(position.x) && (0..max_y).cover?(position.y)
  end

  def [](x, y)
    @map[x][y]
  end

  def []=(x, y, value)
    @map[x][y] = value
  end

  def add_unit(unit)
    @units << unit
  end

  def garbage_collect_units
    live_units, dead_units = @units.partition { |u| u.alive? }
    @units = live_units
    dead_units
  end

  def stuff_around_position(position, radius, &block)
    (-radius..radius).each do |dx|
      (-radius..radius).each do |dy|
        pos = position.move(dx: dx, dy: dy)
        next unless valid_position?(pos)
        yield *stuff_at_position(pos)
      end
    end
  end

  def stuff_at_position(position)
    unit_list = units.select { |u| u.position == position }
    [@map[position.x][position.y], unit_list, position]
  rescue
    p position
  end

  def each_position(&block)
    (0..max_x).each do |x|
      (0..max_y).each do |y|
        yield *stuff_at_position(position_class.new(x: x, y: y))
      end
    end
  end

end

def direction_data
  [-1, 0, -1, 1, 0, 1, 1, 1, 1, 0, 1, -1, 0, -1, -1, -1]
end

def random_direction_deltas
  [rand(-1..1), rand(-1..1)]
end



# line 6080
def prompt_for_course
  begin
    print "Course (1-8)? "
    c1 = STDIN.gets.to_i
  end until (1..8).cover?(c1)
  direction_data.each_slice(2).to_a[c1- 1]
end

def prompt_for_power(max_power)
  begin
    print "Power available: #{max_power} units.  Power to use? "
    p = STDIN.gets.to_i
  end until (0..max_power).cover?(p)
  p
end

def prompt_for_fuel(max_fuel)
  begin
    print "Fuel available: #{max_fuel} pounds.  Fuel to use? "
    f = STDIN.gets.to_i
  end until (0..max_fuel).cover?(f)
  f
end

# line 1040
def command_navigation
  unless $player.system_ok?(:engines)
    puts "Engines are under repair #{$n}."
    return
  end
  unless $player.system_manned?(:engines)
    puts "Not enough crew to man the engines #{$n}."
    return
  end
  d1 = 1 - ((0.23 * rand) * ($depth <= 50 ? 0 : 1))
  x1, y1 = prompt_for_course
  p1 = prompt_for_power($player.power)
  pos = $player.position
  q1 = 1
  # line 1240
  outcome = catch(:end_movement) do
    (1..(p1 / 100 * d1)).each do |x2|
      pos = $player.move(dx: x1, dy: y1)
      unless valid_position?(pos)
        puts "You cannot leave the area #{$n}!!" 
        throw :end_movement
      end
      if $world.map[pos.x][pos.y] == 1
        puts "You almost ran aground #{$n}!!"
        throw :end_movement
      end
      possible_collisions = $world.units.select { |u| u.position == pos }
      possible_collisions.each do |other_unit|
        case other_unit.class.to_s
        when 'Ship'
          # TODO depth checking
          puts "You rammed a ship!!! You're both sunk #{$n}!!"
          throw :game
        when 'Headquarters'
          if $player.depth <= 50
            puts "You rammed your headquarters!! You're sunk!!"
            throw :game
          end
        when 'Mine'
          puts "You've been blown up by a mine #{$n}!!"
          throw :game
        when 'Monster'
          if rand >= 0.21
            puts "You were eaten by a sea monster #{$n}!!"
            throw :game
          end
        else raise
        end
      end
      $player.position = pos
      $player.spend_power(100)
      # line 1520; sea monster check
      $player.position.each_position_within_radius(2) do |pos|
        next unless valid_position?(pos)
        next unless $a[pos.x][pos.y] == 6
        if rand < 0.25
          puts "You were eaten by a sea monster #{$n}!!"
          throw :game
        else
          next if q1 == 0
          puts "You just had a narrow escape with a sea monster #{$n}!!"
          q1 = 0
        end
      end # sea monster check
    end # move loop
  end # catch end movement
  # line 1640
  puts "Navigation complete.  Power left=#{$player.power}."
  true
end

def command_sonar
  # line 1680
  unless $player.system_ok?(:sonar)
    puts "Sonar is under repair #{$n}."
    return
  end
  unless $player.system_manned?(:sonar)
    puts "Not enough crew to work sonar #{$n}."
    return
  end
  begin
    print "Option #? "
    o = STDIN.gets.to_i
  end until [0,1].include?(o)
  if o == 0
    # line 1790
    $world.each_position do |map, units, pos|
      symbol = units.empty? ? '.' : units.first.symbol
      symbol = '#' if map == 1
      print symbol
      puts if pos.y == $world.max_y
    end
    puts
    $player.spend_power(50)
  elsif o == 1
    # line 2010; directional information
    puts "%10s %10s %12s" % ['Direction', '# of Ships', 'Distances']
    # result.each do |k,v|
    #   puts "%10s %10s %12s" % [k, v.length, v.join(',')]
    # end
    puts
  end
  false
end

def command_torpedo
  # line 2220
  unless $player.system_ok?(:torpedos)
    puts "Torpedo tubes are under repair #{$n}."
    return
  end
  unless $player.system_manned?(:torpedos)
    puts "Not enough crew to fire torpedo #{$n}."
    return
  end
  unless $player.torpedos > 0
    puts "No torpedos left #{$n}."
    return
  end
  if $depth >= 2000 and rand <= 0.5
    puts "Pressure implodes sub upon firing....You're crushed!!"
    throw :game
  end
  x1, y1 = prompt_for_course
  pos = $player.position
  # line 2390
  range = 7 - ($depth > 50 ? 5 : 0) - rand(1..4)
  $player.torpedos -= 1
  $player.spend_power(150)
  torpedo_live = true
  (1..range).each do |x2|
    pos = pos.move(dx: x1, dy: y1)
    print "..!.." 
    unless valid_position?(pos) 
      puts "Torpedo out of sonar range....ineffectual #{$n}"
      return true
    end
    $world.units.select { |u| u.position == pos }.each do |unit|
      case unit.class.to_s
      when 'Ship'
        unit.kill
        puts "Ouch!!! You got one #{$n}!!!"
        torpedo_live = false
      when 'Monster'
      when 'Mine'
      when 'Headquarters'
      else raise
      end
    end
    # old code
    if (0..19).cover?(x + x1) and (0..19).cover?(y + y1)
      case $a[x+x1][y+y1]
      when 1
        puts "You took out some island #{$n}!"
        $a[x+x1][y+y1] = 0
      when 4
        puts "You blew up your headquarters #{$n}!!!"
        $s3 = 0; $s4 = 0; $d2 = 0
        $a[x+x1][y+y1] = 0
      when 5
        puts "BLAM!! Shot wasted on a mine #{$n}!!"
        $a[x+x1][y+y1] = 0
      when 6
        puts "A sea monster had a torpedo for lunch #{$n}!!"
      end
    end
    break unless torpedo_live
  end
  if torpedo_live
    puts "dud."
  end
  true
end

def command_missle
  # line 2680
  unless $player.system_ok?(:missles)
    puts "Missle silos are under repair #{$n}."
    return
  end 
  unless $player.system_manned?(:missles)
    puts "Not enough crew to launch a missle #{$n}."
    return
  end
  unless $player.missles > 0
    puts "No missles left #{$n}."
    return
  end
  unless $player.at_missle_depth?
    print 'Recommend that you not fire at this depth...Proceed? '
    choice = STDIN.gets.strip
    return if /n/i === choice
    if rand >= 0.5
      puts "Missle explodes upon firing #{$n}!!  You're dead!!"
      throw :game
    end
  end
  x1, y1 = prompt_for_course
  f1 = prompt_for_fuel($player.fuel)
  $player.missles -= 1
  $player.spend_fuel(f1)
  $player.spend_power(300)
  pos = $player.position
  begin
    f1 -= 75
    pos = pos.move(dx: x1, dy: y1)
    unless valid_position?(pos)
      puts "Missle out of sonar tracking #{$n}. Missle lost."
      return true
    end
  end until f1 < 75
  missle_kills = Hash.new(0)
  pos.each_position_within_radius(1) do |position|
    $world.units.select { |u| u.position == position }.each do |unit|
      unit.kill
      missle_kills[unit.class] += 1
    end
    # legacy map handling
    missle_kills[:island] += 1 if $a[position.x][position.y] == 1
    $a[position.x][position.y] = 0
  end
  missle_kills.each do |k,v|
    case k
    when :island then puts "You blew out some island #{$n}."
    when Mine then puts "You destroyed #{v} mines #{$n}."
    when Monster then puts "You got #{v} sea monsters #{$n}!!! Good work!!"
    when Headquarters then puts "You blew up your headquarters #{$n}!!"
    end
  end
  puts "You destroyed #{missle_kills[Ship]} enemy ships #{$n}!!!"
  if missle_kills.has_key?(Player)
    puts "You blew yourself up!!"
    throw :game
  end
  true
end

def command_manuevering
  unless $player.system_ok?(:maneuvering)
    puts "Ballast controls are being repaired #{$n}."
    return
  end
  unless $player.system_manned?(:maneuvering)
    puts "There are not enough crew to work the controls #{$n}."
    return
  end
  begin
    print "New depth? "
    d1 = STDIN.gets.to_i
  end until d1 > 0
  if d1 >= 3000
    puts "Hull crushed by pressure #{$n}!!"
    throw :game
  end
  power_required = ($player.depth - d1).abs / 2
  $player.spend_power(power_required)
  $player.position = $player.move(z: d1)
  puts "Manuever complete.  Power loss=#{power_required}"
  true
end

def command_status
  unless $player.system_ok?(:status)
    puts "No reports are able to get through #{$n}."
    return
  end
  unless $player.system_manned?(:status)
    puts "No one left to give the report #{$n}."
    return
  end
  enemy_ships = $world.units.inject(0) { |acc, u| u.is_a?(Ship) ? acc + 1 : acc }
  puts "# of enemy ships left.......#{enemy_ships}"
  puts "# of power units left.......#{$player.power}"
  puts "# of torpedos left..........#{$player.torpedos}"
  puts "# of crewmen left...........#{$player.crew}"
  puts "lbs. of fuel left...........#{$player.fuel}"
  puts
  # print "Want damage report? "
  # return true unless /y/i === STDIN.gets
  puts "%12s %6s (+ good, 0 neutral, - bad)" % ['ITEM', 'DAMAGE']
  puts "%12s %6s" % ['-'*12, '-'*6]
  $player.damage.each do |system, dmg|
    puts "%12s %2.3f" % [system.to_s.capitalize, dmg]
  end
  puts "You are at #{$player.position.to_s}"
  puts
  false
end

def command_headquarters
  unless $player.system_ok?(:headquarters)
    puts "Headquarters is damaged. Unable to help #{$n}."
    return
  end
  if $d2 == 0
    puts "Headquarters is deserted #{$n}."
    return
  end
  $world.units.select { |u| u.is_a?(Headquarters) }.each do |hq|
    next unless hq.position.distance_to($player.position) < 2.5
    if $player.depth > 50
      puts "Unable to comply with docking orders for headquarters at #{hq.position}"
      next
    end
    puts "Divers from headquarters bring out supplies and men."
    $player.add_power(4000)
    $player.add_fuel(1500)
    $player.torpedos = 8
    $player.missles = 2
    $player.crew = 25
    $d2 -= 1
  end
  true
end

def command_sabotage
  unless $player.system_ok?(:sabotage)
    puts "Hatches inaccessible #{$n}. No sabotages possible."
    return
  end
  unless $player.system_manned?(:sabotage)
    puts "Not enough crew to go on a mission #{$n}."
    return
  end
  ships_in_range = []
  monsters_in_range = []
  $player.position.each_position_within_radius(2) do |pos|
    $world.units.each do |u|
      next unless u.position == pos
      ships_in_range << u if u.is_a?(Ship)
      monsters_in_range << u if u.is_a?(Monster)
    end
  end
  puts "There are #{ships_in_range.length} ships in range #{$n}."
  begin
    print "How many men are going #{$n}? "
    q1 = STDIN.gets.to_i
    if $player.crew - q1 < 10
      puts "You must leave at least 10 men on board #{$n}."
      q1 = 0
    end
  end until q1 > 0
  crew_ship_ratio = ships_in_range.length.to_f / q1
  ships_killed = 0
  ships_in_range.each do |ship|
    next if (crew_ship_ratio > (1 - rand)) and (rand + crew_ship_ratio < 0.9)
    ship.kill
    ships_killed += 1
  end
  puts "#{ships_killed} ships were destroyed #{$n}."
  accidents = (1..q1).inject(0) { |acc, v| rand > 0.6 ? acc + 1 : acc } 
  meals = 0
  unless monsters_in_range.empty?
    meals = (1..q1 - accidents).inject(0) { |acc, v| rand < 0.15 ? acc + 1 : acc }
    puts "A sea monster smells the men on the way back!!!"
    puts "#{meals} men were eaten #{$n}!!"
    $player.crew -= meals
  end
  puts "#{accidents} men were lost through accidents #{$n}."
  $player.crew -= accidents
  $player.spend_power(10 * q1 + rand * 10)
  true
end

def command_conversion
  unless $player.system_ok?(:converter)
    puts "Power converter is damaged #{$n}."
    return
  end
  unless $player.system_manned?(:converter)
    puts "Not enough men to work the converter #{$n}."
    return
  end
  begin
    print "Option? (1 = fuel to power, 2 = power to fuel)? "
    o = STDIN.gets.to_i
  end until o == 1 or o == 2
  case o
  when 1
    c1 = prompt_for_fuel($f)
    $player.spend_fuel(c1)
    $player.add_power(c1.to_f / 3)
  when 2
    c1 = prompt_for_power($player.power)
    $player.spend_power(c1)
    $player.add_fuel(c1 * 3)
  end
  puts "Conversion complete. Power=#{$player.power}, fuel=#{$player.fuel}"
  true
end

def command_surrender
  puts "Coward!! You're not very patriotic #{$n}!!!"
  throw :game
end

def move_unit(original_x, original_y, new_x, new_y)
  $a[new_x][new_y] = $a[original_x][original_y]
  $a[original_x][original_y] = 0
end

def move_ship_at(x, y, dx = $d8, dy = $d9)
  tx = x + dx 
  ty = y + dy
  tx = 20 - tx if tx > 19
  tx = -tx if tx < 0
  ty = 20 - ty if ty > 19
  ty = -ty if ty < 0
  case $a[tx][ty]
  when 0
    move_unit(x, y, tx, ty)
  when 1
    move_ship_at(x, y, *random_direction_deltas)
  when 2
    if $depth <= 50
      puts "*** You've been rammed by a ship #{$n}!!!"
      move_unit(x, y, tx, ty)
    end
  when 4
    if rand <= 0.15
      puts "*** Your headquarters was rammed #{$n}!!!"
      $s3 = 0; $s4 = 0; $d2 = 0
      move_unit(x, y, tx, ty)
    else
      move_ship_at(x, y, *random_direction_deltas)
    end
  when 5
    puts "*** Ship destroyed by a mine #{$n}!!!"
    move_unit(x, y, tx, ty)
    $a[tx][ty] = 0
    $s -= 1
    throw(:game, true) if $s == 0
  when 6
    if rand > 0.8
      puts "*** Ship eaten by a sea monster #{$n}!!"
      $s -= 1
      $a[x][y] = 0
    else
      move_ship_at(x, y, *random_direction_deltas)
    end
  end
end

def move_monster_at(x, y, dx = $m1, dy = $m2)
  tx = x + dx 
  ty = y + dy
  tx = 20 - tx if tx > 19
  tx = -tx if tx < 0
  ty = 20 - ty if ty > 19
  ty = -ty if ty < 0
  case $a[tx][ty]
  when 0
    move_unit(x, y, tx, ty)
  when 1
    move_monster_at(x, y, *random_direction_deltas)
  when 2
    puts "*** You've been eaten by a sea monster #{$n}!!"
    throw :game
  when 3
    if rand > 0.2
      move_monster_at(x, y, *random_direction_deltas)
    else
      puts "*** Ship eaten by a sea monster #{$n}!!"
      move_unit(x, y, tx, ty)
      $s -= 1
      throw(:game, true) if $s == 0
    end
  when 4
    puts "A sea monster ate your headquarters #{$n}!!"
    $s3 = 0; $s4 = 0; $d2 = 0
    move_unit(x, y, tx, ty)
  when 5
    move_unit(x, y, tx, ty)
  when 6
    if rand < 0.75
      move_monster_at(x, y, *random_direction_deltas)
    else
      puts "*** A sea monster fight #{$n}!!!"
      if rand < 0.8
        puts "It's a tie!!"
        move_monster_at(x, y, *random_direction_deltas)
      else
        puts "And one dies!!"
        move_unit(x, y, tx, ty)
      end
    end
  end
end


def play_seabattle
  $world = World.new

  print 'What is your name? '
  $n = STDIN.gets.strip
  puts

  # sub; line 410
  $player = Player.new(position: Position.new(x: 9, y: 9, z: 100))
  $world.add_unit($player)

  # enemy ships
  enemy_ship_count = rand(16..30)
  enemy_ship_count.times do
    pos = $world.random_unused_location
    $world.add_unit(Ship.new(position: pos))
  end
  puts "You must destroy #{enemy_ship_count} enemy ships to win, #{$n}."
  # line 460
  begin
    $d8, $d9 = random_direction_deltas
  end until ($d8.abs + $d9.abs > 0)
  begin
    $m1, $m2 = random_direction_deltas
  end until ($m1.abs + $m2.abs > 0)
  # headquarters
  pos = $world.random_unused_location
  $world.add_unit(Headquarters.new(position: pos))
  # underwater mines
  (rand(8..16)).times do
    pos = $world.random_unused_location
    $world.add_unit(Mine.new(position: pos))
  end
  # sea monsters
  4.times do
    pos = $world.random_unused_location
    $world.add_unit(Monster.new(position: pos))
  end
  # line 800; set starting values
  $d2 = 2
  # line 890; command section
  outcome = catch(:game) do
    loop do
      p $player.damage
      puts
      puts
      begin
        print "What are your orders #{$n}? "
        user_input = STDIN.gets.strip
        unless /\d+/ === user_input 
          puts <<-COMMANDS
The commands are:
#0: Navigation
#1: Sonar
#2: Torpedo control
#3: Polaris missle control
#4: Manuevering
#5: Status/Damage report
#6: Headquarters
#7: Sabotage
#8: Power conversion
#9: Surrender
          COMMANDS
        end
        o = user_input.to_i
        use_turn = case o
                   when 0 then command_navigation
                   when 1 then command_sonar
                   when 2 then command_torpedo
                   when 3 then command_missle
                   when 4 then command_manuevering
                   when 5 then command_status
                   when 6 then command_headquarters
                   when 7 then command_sabotage
                   when 8 then command_conversion
                   when 9 then command_surrender
                   else false
                   end
      end until use_turn
      # line 4690; retaliation section
      q = 0
      $player.position.each_position_within_radius(4) do |pos|
        next unless valid_position?(pos)
        $world.units.each do |unit|
          if unit.is_a?(Ship) and unit.position == pos
            q += (rand / $player.position.distance_to(unit.position))
          end
        end
      end
      if q == 0
        puts "No ships in range to depth charge you #{$n}!!"
      else
        puts "Depth charges off #{rand > 0.5 ? 'port' : 'starboard'} side #{$n}!!!"
        if q <= 0.13 and rand <= 0.92
          puts "No real damage sustained #{$n}."
        elsif q <= 0.36 and rand <= 0.96
          puts "Light, superficial damage #{$n}."
          $player.spend_power(50)
          $player.damage_random_system { rand * 2 }
        elsif q <= 0.6 and rand <= 0.975
          puts "Moderate damage.  Repairs needed."
          $player.spend_power(75 + rand(1..30))
          2.times { $player.damage_random_system { rand * 8 } }
        elsif q <= 0.9 and rand <= 0.983
          puts "Heavy damage!! Repairs immediate #{$n}!!!"
          $player.spend_power(200 + rand * 76)
          rand(4..6).times { $player.damage_random_system { rand * 11 } }
        else
          puts "Damage critical!!!! We need help!!!"
          code = rand(1000..'zzzz'.to_i(36))
          puts "Send 'HELP' in code.  Here is the code: #{code.to_s(36)}"
          timer = Thread.new { sleep 30 }
          print "Enter code: "
          b = STDIN.gets
          unless b.to_i(36) == code and timer.alive?
            puts "Message garbled #{$n}... No help arrives!!!"
            throw :game
          end
          puts "Fast work #{$n}!! Help arrives in time to save you!!!"
        end
      end
      # line 5210; move ships and sea monsters
      # check battle damage
      if $player.fatally_damaged?
        puts "Damage too much #{$n}!!! You're sunk!!"
        throw :game
      end
      puts "\n\n---*** Result of last enemy maneuver ***---"
      $world.units.each do |unit|
        unit.play_turn if unit.respond_to?(:play_turn)
      end
      (0..19).each do |x|
        (0..19).each do |y|
          case $a[x][y]
          when 6 then move_monster_at(x, y)
          end
        end
      end
      9.times { $player.repair_random_system }

      # garbage collect the units array
      $world.units.delete_if { |unit| ! unit.alive? }
      throw(:game, true) if $world.units.none? { |u| u.is_a?(Ship) }
    end # game loop
  end # catch

  puts 'Game over.'
  puts outcome ? 'You win' : 'You lose'

end
