use Gtk;

init Gtk;

create_text();

main Gtk;

sub destroy_window
{
  Gtk->main_quit;
}

sub create_text 
{
   my($box1,
      $box2,$button,$separator,$table,$hscrollbar,$vscrollbar,$text);
	
	if (not defined $text_window) {
		$text_window = new Gtk::Window "toplevel";
		$text_window->set_name("text window");
		$text_window->signal_connect("destroy", \&destroy_window, \$text_window);
		$text_window->signal_connect("delete_event", \&destroy_window, \$text_window);
		$text_window->set_title("test");
		$text_window->border_width(0);
		
		$box1 = new Gtk::VBox(0,0);
		$text_window->add($box1);
		$box1->show;
		
		$box2 = new Gtk::VBox(0,10);
		$box2->border_width(10);
		$box1->pack_start($box2,1,1,0);
		$box2->show;
		
		$table = new Gtk::Table(2,2,0);
		$table->set_row_spacing(0,2);
		$table->set_col_spacing(0,2);
		$box2->pack_start($table,1,1,0);
		$table->show;
		
		$text = new Gtk::Text(undef,undef);
		$table->attach_defaults($text, 0,1,0,1);
		show $text;
		

		$vscrollbar = new Gtk::VScrollbar($text->vadj);
		$table->attach($vscrollbar, 1, 2,0,1,[-fill],[-expand,-fill],0,0);
		$vscrollbar->show;
		
		$text->freeze;
		$text->realize;
		
		$text->insert(undef,$text->style->black,undef, "spencer blah blah blah blah blah blah blah blah blah\n");
		$text->insert(undef,$text->style->black,undef, "kimball\n");
		$text->insert(undef,$text->style->black,undef, "is\n");
		$text->insert(undef,$text->style->black,undef, "a\n");
		$text->insert(undef,$text->style->black,undef, "wuss.\n");
		$text->insert(undef,$text->style->black,undef, "but\n");
		$text->insert(undef,$text->style->black,undef, "josephine\n");
		$text->insert(undef,$text->style->black,undef, "(his\n");
		$text->insert(undef,$text->style->black,undef, "girlfriend\n");
		$text->insert(undef,$text->style->black,undef, "is\n");
		$text->insert(undef,$text->style->black,undef, "not).\n");
		$text->insert(undef,$text->style->black,undef, "why?\n");
		$text->insert(undef,$text->style->black,undef, "because\n");
		$text->insert(undef,$text->style->black,undef, "spencer\n");
		$text->insert(undef,$text->style->black,undef, "puked\n");
		$text->insert(undef,$text->style->black,undef, "last\n");
		$text->insert(undef,$text->style->black,undef, "night\n");
		$text->insert(undef,$text->style->black,undef, "but\n");
		$text->insert(undef,$text->style->black,undef, "josephine\n");
		$text->insert(undef,$text->style->black,undef, "did\n");
		$text->insert(undef,$text->style->black,undef, "not");
		$text->insert(undef,$text->style->black,undef, "whereas\n");
		$text->insert(undef,$text->style->black,undef, "kenneth\n");
		$text->insert(undef,$text->style->black,undef, "is\n");
		$text->insert(undef,$text->style->black,undef, "undoubtedly\n");
		$text->insert(undef,$text->style->black,undef, "more\n");
		$text->insert(undef,$text->style->black,undef, "wussful\n");
		$text->insert(undef,$text->style->black,undef, "by default\nn");
		$text->insert(undef,$text->style->black,undef, "not\n");
		$text->insert(undef,$text->style->black,undef, "having\n");
		$text->insert(undef,$text->style->black,undef, "any\n");
		$text->insert(undef,$text->style->black,undef, "more\n");
		$text->insert(undef,$text->style->black,undef, "information\n");
		$text->insert(undef,$text->style->black,undef, "to\n");
		$text->insert(undef,$text->style->black,undef, "base\n");
		$text->insert(undef,$text->style->black,undef, "a\n");
		$text->insert(undef,$text->style->black,undef, "comparison on\n");

		
		$text->thaw;

		$separator = new Gtk::HSeparator();
		$box1->pack_start($separator,0,1,0);
		$separator->show;
		
		$box2 = new Gtk::VBox(0,10);
		$box2->border_width(10);
		$box1->pack_start($box2, 0, 1, 0);
		$box2->show;
		
		$button = new Gtk::Button "close";
		$button->signal_connect("clicked", sub {destroy $text_window});
		$box2->pack_start($button, 1, 1, 0);
		$button->can_default(1);
		$button->grab_default;
		$button->show;
		
	}
	if (!visible $text_window) {
		show $text_window;
	} else {
		destroy $text_window;
	}
}
