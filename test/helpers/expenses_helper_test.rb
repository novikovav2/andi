require "test_helper"

class ExpensesHelperTest < ActionView::TestCase
  test "formats expense share weights without trailing zeros" do
    assert_equal "8", format_expense_share_weight(BigDecimal("8.0"))
    assert_equal "1", format_expense_share_weight(BigDecimal("1.000"))
    assert_equal "0.5", format_expense_share_weight(BigDecimal("0.50"))
    assert_equal "1.25", format_expense_share_weight(BigDecimal("1.250"))
  end

  test "formats expense share total label" do
    assert_equal "1 единица", expense_share_total_label([ BigDecimal("1.0") ])
    assert_equal "9 единиц", expense_share_total_label([ 7, 1, 1 ])
    assert_equal "1.75 единицы", expense_share_total_label([ BigDecimal("0.5"), BigDecimal("1.25") ])
  end

  test "formats expense share bar width" do
    assert_equal "100%", expense_share_bar_width(7, 7)
    assert_equal "14.29%", expense_share_bar_width(1, 7)
    assert_equal "0%", expense_share_bar_width(0, 7)
    assert_equal "0%", expense_share_bar_width(1, 0)
  end
end
