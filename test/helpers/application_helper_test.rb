require "test_helper"

class ApplicationHelperTest < ActionView::TestCase
  include ActiveSupport::Testing::TimeHelpers

  test "time ago in russian formats recent times naturally" do
    travel_to Time.zone.local(2026, 6, 19, 12, 0, 0) do
      assert_equal "Только что", time_ago_in_russian(Time.current)
      assert_equal "1 минуту назад", time_ago_in_russian(1.minute.ago)
      assert_equal "2 минуты назад", time_ago_in_russian(2.minutes.ago)
      assert_equal "5 минут назад", time_ago_in_russian(5.minutes.ago)
      assert_equal "21 минуту назад", time_ago_in_russian(21.minutes.ago)
      assert_equal "1 час назад", time_ago_in_russian(1.hour.ago)
      assert_equal "2 часа назад", time_ago_in_russian(2.hours.ago)
      assert_equal "5 часов назад", time_ago_in_russian(5.hours.ago)
      assert_equal "1 день назад", time_ago_in_russian(1.day.ago)
      assert_equal "2 дня назад", time_ago_in_russian(2.days.ago)
      assert_equal "5 дней назад", time_ago_in_russian(5.days.ago)
      assert_equal "19.05.2026", time_ago_in_russian(31.days.ago)
    end
  end

  test "time ago in russian returns blank for blank time" do
    assert_equal "", time_ago_in_russian(nil)
  end
end
