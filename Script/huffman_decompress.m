function [output] = huffman_decompress(input, huff_dict)
output = [];
code = '';

for i = 1:length(input)
    code = [code input(i)]; % append the previous "code" and an actual input
    index = find(strcmp(huff_dict(:, 2), code), 1); % compares the current code with all codes in the dictionary and returns the row index of the first matching code

    if ~isempty(index) % if an index is not empty and some row index was retrieved in the previous step
        output = [output; huff_dict{index, 1}]; % adds to the output the unique number fron huff_dict with the same index
        code = ''; % erases the code for the next step
    end
end
end