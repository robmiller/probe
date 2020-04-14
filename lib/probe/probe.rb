require "typhoeus"
require "nokogiri"

class Probe
  def initialize(url, name: "")
    @url = url
    @name = name
  end

  def title
    doc.at_css("title").inner_text
  end

  def cms
    # A rough heuristic.
    scores = {
      "WordPress" => 0.0,
      "Shopify" => 0.0,
    }

    # Is there a meta generator tag?
    generators = doc.css("meta[name='generator']").map { |g| g["content"] }
    if generators.any?(/WordPress|Woo Framework|WooCommerce/)
      scores["WordPress"] += 0.75
    end

    # Is there a DNS prefetch?
    dp = doc.css("link[rel='dns-prefetch']").map { |d| d["href"] }
    if dp.any?(/s\.w\.org$/)
      scores["WordPress"] += 0.5
    end

    # Shopify sites will have scripts loading from the Shopify CDN
    scripts = doc.css("script").map { |s| s["src"] }
    if scripts.any?(/cdn\.shopify\.com/)
      scores["Shopify"] += 0.5
    end

    # WordPress sites will have a wp-admin URL
    wpadmin_urls = ["wp-admin", "admin", "wp-login.php"]
    responses = wpadmin_urls.map do |wpadmin_url|
      Typhoeus.get(@url + "/" + wpadmin_url, followlocation: true)
    end

    if responses.any? { |r| r.code == 200 && r.body =~ /wp-submit/ }
      scores["WordPress"] += 10
    else
      scores["WordPress"] -= 0.5
    end

    # Shopify sites will have an admin URL that redirects to Shopify
    shopify_admin = Typhoeus.get(@url + "/admin", followlocation: false)
    if shopify_admin.headers["location"] =~ /shopify/
      scores["Shopify"] += 10
    end

    guess = scores.select { |k, v| v >= 1.0 }.sort_by { |k, v| v }&.last&.first

    if guess
      guess
    else
      "Unknown"
    end
  end

  def html
    @html ||=
      begin
        request = Typhoeus::Request.new(@url, followlocation: true)
        @response = request.run
        unless @response.code == 200
          warn "Didn't get a 200 on #{@url}"
        end

        @response.body
      end
  end

  def doc
    @doc ||= Nokogiri::HTML(html)
  end
end
