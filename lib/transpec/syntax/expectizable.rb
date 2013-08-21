# coding: utf-8

require 'transpec/syntax/send_node_syntax'

module Transpec
  class Syntax
    module Expectizable
      include SendNodeSyntax

      def wrap_subject_in_expect!
        if subject_range.source[0] == '('
          insert_before(subject_range, 'expect')
        else
          insert_before(subject_range, 'expect(')
          insert_after(subject_range, ')')
        end
      end
    end
  end
end
