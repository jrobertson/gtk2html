# Introducing the Gtk2HTML gem

    require 'gtk2html'


    s =<<EOF
    <html>
     <div>
       test
      </div>
    </html>
    EOF


    app = Gtk2HTML::Main.new s, irb: true

The above code renders HTML within the Gtk2 application as show in the screenshot below:

![Screenshot of rendered HTML in the Gtk2HTML application](http://www.jamesrobertson.eu/r/images/2015/nov/25/screenshot-of-gtk2html.png)

gtk2html gtk2 html
