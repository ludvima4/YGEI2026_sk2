% Huffam coding
function [output, huffman_dict] = huffman_compres(input)

% 1 - NUMBER OF UNIQUE VALUES
[C,ia,ic] = unique(input); % C = unique values, ia = indices of first occurrences, ic = indices mapping input values to C
input_counts = accumarray(ic,1); % count the frequency of each unique value
value_counts = [C, input_counts]; % matrix containig unique values and their frequencies
value_testing = value_counts;

% 2 - SORTING ROWS BY FREQUENCY
value_asc = sortrows(value_testing, 2, "ascend");

% 3 - INICIALIZING OF HUFFMAN TREE
n = size(value_asc, 1); % unique numbers count
active = (1:n)'; % vector of nodes ID
tree = [(1:n)' value_asc(:,2) zeros(n,2)]; % Huffman tree

% 4 - CONSTRUCTION OF THE HUFFMAN TREE
% first two indexes are always those eith the lowest frequency
while length(active) > 1 % runs until every node is completed

    % Sorting active nodes by frequnecy
    sorted = sortrows(tree(active, 1:2), 2); % selection of the frequency of the first two unique indices
    active = sorted(:,1); % all current unique indexes

    left = active(1); % left child is the first unique index
    right = active(2); % right child is the second unique index

    freq = tree(left, 2) + tree(right, 2); % sum of the frequencies of the first two unique indices

    id = size(tree, 1) + 1; % id for a new node

    tree = [tree; id freq left right]; % update of the tree content

    active(1:2) = []; % deletion of the first two unique indexes (because we have already solved them)
    active = [active; id]; % addition of the new node's ID

end

% 5 - HUFFMAN CODE GENERATING
binar_index = cell(n,1); % creating a space that can contain elements of various data types
root = active(1); % the value of the last node — the one with the highest frequency

for i = 1:n
    node = i;
    code = '';

    while node ~= root % until the index of the current node matches the value of the root node (i.e., the last one)
        parent = find(tree(:, 3) == node | tree(:, 4) == node); % searching for the node that is the parent of the current node

        if tree(parent, 3) == node % if the left child has the same value as the current node...
            code = ['0', code]; % ... assign it index 0
        else % if the right child has the same value as the current node...
            code = ['1', code]; % ... assign it index 1 (for the second and last iteration it works so that the new index is added to the front)
        end

        node = parent; % move on to the next node

    end

    binar_index{i} = code; % gradually filled with code values

end

% Only one unique value: the tree has no branches, assign code '0'
if n == 1
    binar_index{1} = '0';
end

huffman_dict = [num2cell(value_asc(:,1)), binar_index]; % the resulting matrix of the index and codes assigned to them

% 6 - DATA APPLICATION
output = '';

for i = 1:length(input)
    index = find(value_asc(:,1) == input(i), 1); % searching for identical indices (numbers) in the original file and the file containing unique values

    output = [output binar_index{index}]; % append an index of 1 or 0 to the output for the corresponding index i
end
end
