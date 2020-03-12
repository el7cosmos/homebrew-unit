class UnitJava < Formula
  desc "Java module for Unit application server"
  homepage "https://unit.nginx.org"
  url "https://unit.nginx.org/download/unit-1.16.0.tar.gz"
  sha256 "6a5954c16a9f940b4ef6e40331e854f5ae7b954838991fef1db4148b8b97d563"
  head "https://hg.nginx.org/unit", :using => :hg

  depends_on :java
  depends_on "openssl@1.1"
  depends_on "unit@1.16.0"
  uses_from_macos "openjdk"

  def install
    system "./configure",
              "--prefix=#{prefix}",
              "--sbindir=#{bin}",
              "--log=#{var}/log/unit/unit.log",
              "--pid=#{var}/run/unit/unit.pid",
              "--control=unix:#{var}/run/unit/control.sock",
              "--modules=#{HOMEBREW_PREFIX}/lib/unit/modules",
              "--state=#{var}/state/unit",
              "--tmp=/tmp",
              "--openssl",
              "--cc-opt=-I#{Formula["openssl@1.1"].opt_prefix}/include",
              "--ld-opt=-L#{Formula["openssl@1.1"].opt_prefix}/lib"

    inreplace "build/autoconf.data",
        "NXT_MODULES='#{HOMEBREW_PREFIX}/lib/unit/modules'",
        "NXT_MODULES='#{lib}/unit/modules'"

    inreplace "auto/modules/java",
         "$NXT_JAVAC -version 2>&1", "$NXT_JAVAC -version 2>/dev/null"

    system "./configure", "java"
    system "make", "java"
    system "make", "java-install"
  end

  test do
    require "socket"

    server = TCPServer.new(0)
    port = server.addr[1]
    server.close

    expected_output = "Hello world!"
    (testpath/"unit.conf").write <<~EOS
      {
        "listeners": { "*:#{port}": { "pass": "applications/test" } },
        "applications": {
          "test": { "type": "java", "webapp": "#{testpath}" }
        }
      }
    EOS
    (testpath/"index.jsp").write <<~EOS
      <%@ page contentType="text/plain"%>#{expected_output}
    EOS
    (testpath/"state/certs").mkpath

    system "#{HOMEBREW_PREFIX}/bin/unitd", "--log", "#{testpath}/unit.log",
                        "--control", "unix:#{testpath}/control.sock",
                        "--pid", "#{testpath}/unit.pid",
                        "--state", "#{testpath}/state"
    sleep 3

    pid = File.open(testpath/"unit.pid").gets.chop.to_i

    system "curl", "-s", "--unix-socket", "#{testpath}/control.sock",
                    "-X", "PUT",
                    "-d", "@#{testpath}/unit.conf", "127.0.0.1/config"

    assert_match expected_output, shell_output("curl -s 127.0.0.1:#{port}")
  ensure
    Process.kill("TERM", pid)
  end
end
