class MattermostController < BaseController
  skip_before_filter :verify_authenticity_token

  def callback
    method = params['type'] == 'dialog_submission' ? :receive : :entry
    raise ArgumentError if method == :entry && params['token'] != ENV['MATTERMOST_TOKEN']

    res = EpriSheet::Bot.send(method, params)
    text = res && res.key?(:error) ? res[:error] : ''
    json = {response_type: 'ephemeral', username: 'Met3r', text: text}
    render json: json
  end
end