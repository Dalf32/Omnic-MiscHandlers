# pick_handler.rb
#
# AUTHOR::  Kyle Mullins

class PickHandler < CommandHandler
  command(:pick, :pick)
    .min_args(1).usage('pick [options]').description('Chooses one of the given options.')

  def pick(_event, *options)
    options.sample
  end
end
