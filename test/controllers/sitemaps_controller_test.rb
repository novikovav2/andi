require "test_helper"

class SitemapsControllerTest < ActionDispatch::IntegrationTest
  test "returns xml sitemap with seo pages only" do
    get "/sitemap.xml"

    assert_response :success
    assert_equal "application/xml", response.media_type

    assert_includes response.body, "<loc>#{root_url}</loc>"
    assert_includes response.body, "<loc>#{trip_expenses_url}</loc>"
    assert_includes response.body, "<loc>#{picnic_expenses_url}</loc>"
    assert_includes response.body, "<loc>http://www.example.com/trip-expenses</loc>"
    assert_includes response.body, "<loc>http://www.example.com/picnic-expenses</loc>"
    assert_includes response.body, "<loc>#{party_expenses_url}</loc>"
    assert_includes response.body, "<loc>http://www.example.com/party-expenses</loc>"
    assert_includes response.body, "<loc>#{who_owes_whom_url}</loc>"
    assert_includes response.body, "<loc>http://www.example.com/who-owes-whom</loc>"
    assert_includes response.body, "<loc>#{privacy_url}</loc>"
    assert_includes response.body, "<loc>#{terms_url}</loc>"

    assert_includes response.body, "<lastmod>#{Date.current.iso8601}</lastmod>"
    assert_includes response.body, "<changefreq>weekly</changefreq>"
    assert_includes response.body, "<changefreq>yearly</changefreq>"
    assert_includes response.body, "<priority>1.0</priority>"
    assert_includes response.body, "<priority>0.8</priority>"
    assert_includes response.body, "<priority>0.3</priority>"
    assert_match %r{<loc>#{trip_expenses_url}</loc>\s*<lastmod>.*?</lastmod>\s*<changefreq>weekly</changefreq>\s*<priority>0.8</priority>}m,
                 response.body
    assert_match %r{<loc>#{picnic_expenses_url}</loc>\s*<lastmod>.*?</lastmod>\s*<changefreq>weekly</changefreq>\s*<priority>0.8</priority>}m,
                 response.body
    assert_match %r{<loc>#{party_expenses_url}</loc>\s*<lastmod>.*?</lastmod>\s*<changefreq>weekly</changefreq>\s*<priority>0.8</priority>}m,
                 response.body
    assert_match %r{<loc>#{who_owes_whom_url}</loc>\s*<lastmod>.*?</lastmod>\s*<changefreq>weekly</changefreq>\s*<priority>0.8</priority>}m,
                 response.body

    refute_includes response.body, "/events/"
    refute_includes response.body, "/expenses/"
    refute_includes response.body, "/participants/"
    refute_includes response.body, "/dashboard"
    refute_includes response.body, "/session"
    refute_includes response.body, "/registration"
    refute_includes response.body, "/admin/"
  end
end
