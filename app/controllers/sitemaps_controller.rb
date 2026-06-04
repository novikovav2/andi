class SitemapsController < ApplicationController
  def show
    render xml: <<~XML
      <?xml version="1.0" encoding="UTF-8"?>
      <urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
        <url>
          <loc>#{root_url}</loc>
          <changefreq>weekly</changefreq>
          <priority>1.0</priority>
        </url>
        <url><loc>#{split_expenses_url}</loc></url>
            <url><loc>#{trip_expenses_url}</loc></url>
            <url><loc>#{picnic_expenses_url}</loc></url>
            <url><loc>#{party_expenses_url}</loc></url>
            <url><loc>#{who_owes_whom_url}</loc></url>
      </urlset>
    XML
  end
end
