package App::Lorem::Tickit::Widget;

use parent 'Tickit::Widget';
use strict;
use warnings;

use Text::Lorem;
use Tickit::Pen;
use Tickit::Widget::Choice;

our $VERSION = 0.01;

sub new {
	my ($class, %args) = @_;

	my $self = $class->SUPER::new(%args);
	$self->{'_counts'} = {
		'paragraphs' => 3,
		'sentences' => 8,
		'words' => 50,
	};
	$self->{'_lorem'} = Text::Lorem->new;
	$self->{'_version'} = $args{'version'} || $VERSION;
	$self->{'_choice'} = Tickit::Widget::Choice->new(
		'choices' => [
			['paragraphs', 'paragraphs'],
			['sentences', 'sentences'],
			['words', 'words'],
		],
		'on_changed' => sub {
			$self->_regenerate;
			$self->redraw;
			return;
		},
	);
	$self->_regenerate;

	return $self;
}

sub CAN_FOCUS {
	return 1;
}

sub cols {
	return 40;
}

sub lines {
	return 10;
}

sub window_gained {
	my $self = shift;

	$self->SUPER::window_gained(@_);
	$self->reshape;

	return;
}

sub window_lost {
	my $self = shift;

	if ($self->{'_choice'}->window) {
		$self->{'_choice'}->window->close;
		$self->{'_choice'}->set_window(undef);
	}

	$self->SUPER::window_lost(@_);

	return;
}

sub on_key {
	my $self = shift;
	my ($ev) = @_;
	my $key = $ev->str;

	if ($key eq '+') {
		$self->_change_count(1);
		return 1;
	} elsif ($key eq '-') {
		$self->_change_count(-1);
		return 1;
	} elsif ($key eq 'Tab' || $key eq 'Down' || $key eq 'Right') {
		$self->_next_choice;
		return 1;
	} elsif ($key eq 'Up' || $key eq 'Left') {
		$self->_prev_choice;
		return 1;
	} elsif ($key eq 'Enter' || $key eq 'Space') {
		$self->_regenerate;
		$self->redraw;
		return 1;
	} elsif ($key eq 'q' || $key eq 'C-c') {
		$self->window->tickit->stop if $self->window;
		return 1;
	}

	return 0;
}

sub reshape {
	my $self = shift;
	my $win = $self->window;

	return if ! $win;

	my $cols = $win->cols;
	my $choice_win = $self->{'_choice'}->window;

	if ($choice_win) {
		$choice_win->change_geometry(0, 0, 1, $cols);
	} else {
		$choice_win = $win->make_sub(0, 0, 1, $cols);
		$self->{'_choice'}->set_window($choice_win);
	}
	$self->{'_choice'}->take_focus;

	return;
}

sub render_to_rb {
	my $self = shift;
	my ($rb, $rect) = @_;
	my $win = $self->window;

	$rb->eraserect($rect, Tickit::Pen->new('bg' => 'black'));
	return if ! $win;

	my $lines = $win->lines;
	my $cols = $win->cols;

	$self->_render_count($rb, 1, $cols);
	$self->_render_text($rb, 3, _max(0, $lines - 5), $cols);
	$self->_render_status($rb, $lines - 1, $cols);

	return;
}

sub _render_count {
	my ($self, $rb, $line, $cols) = @_;

	return if $cols <= 0;

	my $mode = $self->_mode;
	my $count = $self->{'_counts'}->{$mode};
	my $text = 'count: '.$count;

	$rb->text_at($line, 0, $text, Tickit::Pen->new('fg' => 'white', 'bg' => 'black'));

	return;
}

sub _render_text {
	my ($self, $rb, $top, $height, $cols) = @_;

	return if $height <= 0 || $cols <= 0;

	my $width = _max(10, $cols - 4);
	my @wrapped = _wrap_text($self->{'_text'}, $width);
	my $start = $top + int(($height - @wrapped) / 2);
	$start = $top if $start < $top;
	my $max_line = $top + $height - 1;
	my $pen = Tickit::Pen->new('fg' => 'green', 'bg' => 'black');

	for my $i (0 .. $#wrapped) {
		my $line_no = $start + $i;
		last if $line_no > $max_line;
		my $line = $wrapped[$i];
		my $col = int(($cols - length $line) / 2);
		$col = 0 if $col < 0;
		$rb->text_at($line_no, $col, $line, $pen);
	}

	return;
}

sub _render_status {
	my ($self, $rb, $line, $cols) = @_;

	return if $line < 0 || $cols <= 0;

	my $left = '+/- count, Tab choice, Space menu, q quit';
	my $right = 'v'.$self->{'_version'};
	my $pen = Tickit::Pen->new('fg' => 'black', 'bg' => 'white');

	$rb->erase_at($line, 0, $cols, $pen);
	if (length($right) < $cols) {
		my $left_width = $cols - length($right) - 1;
		$left = substr($left, 0, $left_width);
		$rb->text_at($line, 0, $left, $pen);
		$rb->text_at($line, $cols - length($right), $right, $pen);
	} else {
		$rb->text_at($line, 0, substr($right, 0, $cols), $pen);
	}

	return;
}

sub _change_count {
	my ($self, $delta) = @_;

	my $mode = $self->_mode;
	my $value = $self->{'_counts'}->{$mode} + $delta;
	$value = 1 if $value < 1;
	$self->{'_counts'}->{$mode} = $value;
	$self->_regenerate;
	$self->redraw;

	return;
}

sub _next_choice {
	my $self = shift;

	$self->_choose_relative(1);

	return;
}

sub _prev_choice {
	my $self = shift;

	$self->_choose_relative(-1);

	return;
}

sub _regenerate {
	my $self = shift;
	my $mode = $self->_mode;

	if ($mode eq 'paragraphs') {
		my @paragraphs = $self->{'_lorem'}->paragraphs($self->{'_counts'}->{'paragraphs'});
		$self->{'_text'} = join "\n\n", @paragraphs;
	} elsif ($mode eq 'sentences') {
		$self->{'_text'} = $self->{'_lorem'}->sentences($self->{'_counts'}->{'sentences'});
	} else {
		$self->{'_text'} = $self->{'_lorem'}->words($self->{'_counts'}->{'words'});
	}

	return;
}

sub _choose_relative {
	my ($self, $delta) = @_;

	my @modes = qw(paragraphs sentences words);
	my $mode = $self->_mode;
	my ($index) = grep { $modes[$_] eq $mode } 0 .. $#modes;
	$index += $delta;
	$index = $#modes if $index < 0;
	$index = 0 if $index > $#modes;
	$self->{'_choice'}->choose_by_value($modes[$index]);

	return;
}

sub _mode {
	my $self = shift;

	return $self->{'_choice'}->chosen_value;
}

sub _wrap_text {
	my ($text, $width) = @_;

	my @lines;
	foreach my $paragraph (split /\n\n+/, $text) {
		my @words = split /\s+/, $paragraph;
		my $line = '';
		foreach my $word (@words) {
			while (length $word > $width) {
				push @lines, substr($word, 0, $width, '');
			}
			if ($line eq '') {
				$line = $word;
			} elsif (length($line) + 1 + length($word) <= $width) {
				$line .= ' '.$word;
			} else {
				push @lines, $line;
				$line = $word;
			}
		}
		push @lines, $line if $line ne '';
		push @lines, '';
	}
	pop @lines if @lines && $lines[-1] eq '';

	return @lines;
}

sub _min {
	my ($x, $y) = @_;

	return $x < $y ? $x : $y;
}

sub _max {
	my ($x, $y) = @_;

	return $x > $y ? $x : $y;
}

1;

__END__

=pod

=encoding utf8

=head1 NAME

App::Lorem::Tickit::Widget - Tickit widget for lorem ipsum generator.

=head1 SYNOPSIS

 use App::Lorem::Tickit::Widget;

 my $widget = App::Lorem::Tickit::Widget->new(
         'version' => '0.01',
 );

=head1 METHODS

=head2 C<new>

 my $widget = App::Lorem::Tickit::Widget->new(%params);

Constructor.

Returns instance of object.

=head2 C<CAN_FOCUS>

 my $can_focus = $widget->CAN_FOCUS;

Returns true value.

=head2 C<cols>

 my $cols = $widget->cols;

Returns requested number of columns.

=head2 C<lines>

 my $lines = $widget->lines;

Returns requested number of lines.

=head2 C<window_gained>

 $widget->window_gained($window);

Create and place the choice widget window.

=head2 C<window_lost>

 $widget->window_lost($window);

Release the choice widget window.

=head2 C<on_key>

 my $handled = $widget->on_key($event);

Process keyboard event.

=head2 C<reshape>

 $widget->reshape;

Resize and reposition the choice widget window.

=head2 C<render_to_rb>

 $widget->render_to_rb($render_buffer, $rect);

Render widget to Tickit render buffer.

=head1 DEPENDENCIES

L<Text::Lorem>,
L<Tickit::Pen>,
L<Tickit::Widget>,
L<Tickit::Widget::Choice>.

=head1 REPOSITORY

L<https://github.com/michal-josef-spacek/App-Lorem-Tickit>

=head1 AUTHOR

Michal Josef Špaček L<mailto:skim@cpan.org>

L<http://skim.cz>

=head1 LICENSE AND COPYRIGHT

© 2026 Michal Josef Špaček

BSD 2-Clause License

=head1 VERSION

0.01

=cut
