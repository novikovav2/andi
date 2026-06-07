class SitemapsController < ApplicationController
  def show
    render xml: sitemap_xml
  end

  private

  def sitemap_pages
    [
      { loc: root_url, priority: "1.0", changefreq: "weekly" },
      { loc: split_expenses_url, priority: "0.8", changefreq: "monthly" },
      { loc: trip_expenses_url, priority: "0.8", changefreq: "monthly" },
      { loc: picnic_expenses_url, priority: "0.8", changefreq: "monthly" },
      { loc: party_expenses_url, priority: "0.8", changefreq: "monthly" },
      { loc: who_owes_whom_url, priority: "0.8", changefreq: "monthly" },
      { loc: privacy_url, priority: "0.3", changefreq: "yearly" },
      { loc: terms_url, priority: "0.3", changefreq: "yearly" }
    ]
  end

  def sitemap_xml
    lastmod = Date.current.iso8601
    xml = Builder::XmlMarkup.new(indent: 2)

    xml.instruct! :xml, version: "1.0", encoding: "UTF-8"
    xml.urlset xmlns: "http://www.sitemaps.org/schemas/sitemap/0.9" do
      sitemap_pages.each do |page|
        xml.url do
          xml.loc page.fetch(:loc)
          xml.lastmod lastmod
          xml.changefreq page.fetch(:changefreq)
          xml.priority page.fetch(:priority)
        end
      end
    end
  end
end
