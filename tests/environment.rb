require 'test/unit'
require '../lib/oozby'

# unit tests for the easy to test stuff - math functions
class TestEnvironment < Test::Unit::TestCase
  # test lookup function is behaving in a sensible way, like in openscad
  def test_lookup
    env = Oozby::Environment.new(ooz: Oozby.new)
    
    # test data
    table = {-10 => -50, -5 => 0, 5 => 50, 10 => 100, 20 => 120}
    
    assert_equal(-50, env.lookup(-9001, table))
    assert_equal(-50, env.lookup(-20, table))
    assert_equal(-50, env.lookup(-10, table))
    assert_equal(-25, env.lookup(-7.5, table))
    assert_equal(0, env.lookup(-5, table))
    assert_equal(50, env.lookup(5, table))
    assert_equal(75, env.lookup(7.5, table))
    assert_equal(110, env.lookup(15, table))
    assert_equal(120, env.lookup(20, table))
    assert_equal(120, env.lookup(30, table))
    assert_equal(120, env.lookup(9001, table))
  end
  
  # test the trig functions are working right, using degrees
  def test_trig
    env = Oozby::Environment.new(ooz: Oozby.new)
    
    assert_equal( 0.0, env.sin(0))
    assert_equal( 1.0, env.sin(90))
    assert_equal(-1.0, env.sin(-90))
    assert_equal( 1.0, env.cos(0))
    
    assert_equal(45.0, env.atan2(10,10))
    assert_equal(135.0, env.atan2(10,-10))
    assert_equal(60.0, env.acos(0.5))
  end
end