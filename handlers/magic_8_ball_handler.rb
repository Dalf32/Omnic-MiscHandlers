# magic_8_ball_handler.rb
#
# Author::	Kyle Mullins

class Magic8BallHandler < CommandHandler
  command :magic8ball, :magic_8_ball, min_args: 1, description: 'Simulates a Magic 8-Ball'

  def magic_8_ball(_event, *_question)
    [
      'It is certain',
      'It is decidedly so',
      'Without a doubt',
      'Yes, definitely',
      'You may rely on it',
      'As I see it, yes',
      'Most likely',
      'Outlook good',
      'Yes',
      'Signs point to yes',
      'Reply hazy try again',
      'Ask again later',
      'Better not tell you now',
      'Cannot predict now',
      'Concentrate and ask again',
      "Don't count on it",
      'My reply is no',
      'My sources say no',
      'Outlook not so good',
      'Very doubtful'
    ].sample
  end
end
