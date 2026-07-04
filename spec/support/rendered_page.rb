# Wraps a request spec's response body so we can assert on it with
# Capybara's matchers (have_css, have_link, ...) instead of raw string
# matching -- the RSpec equivalent of Minitest's `assert_select`.
module RenderedPageHelper
  def rendered
    Capybara::Node::Simple.new(response.body)
  end
end

RSpec.configure do |config|
  config.include RenderedPageHelper, type: :request
end
