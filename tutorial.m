% Matlab script

%% Some intialization

tol = 1e-12;

D = 12;
d = 3;

A = randcomplex(D, d, D); % MPS tensor
E = ncon({A, conj(A)}, {[-1 1 -3], [-2 1 -4]}); % transfer matrix -> implemented in function CreateTransfer

%% Calculate largest magnitude left and right eigenvectors of transfer matrix

% first option: directly using transfer matrix
[r1, lambda1] = eigs(reshape(E, [D^2, D^2]), 1); % right eigenvector
[l1, ltst1] = eigs(reshape(E, [D^2, D^2]).', 1); % left eigenvector
r1 = reshape(r1, [D D]);
l1 = reshape(l1, [D D]).'; % transpose for indexing convention

% second option: smart way using function handle for eigs
% !have to reshape v to and from matrix in function handle!
handleR = @(v) reshape(ncon({A, conj(A), reshape(v, [D D])}, {[-1 2 1], [-2 2 3], [1 3]}), [], 1); % contraction order good, right?
handleL = @(v) reshape(ncon({A, conj(A), reshape(v, [D D])}, {[1 2 -2], [3 2 -1], [3 1]}), [], 1);
[r2, lambda2] = eigs(handleR, D^2, 1); % right eigenvector
[l2, ltst2] = eigs(handleL, D^2, 1); % left eigenvector
r2 = reshape(r2, [D D]);
l2 = reshape(l2, [D D]);

% check if everything worked out: ok
checkEigenv = ArrayIsEqual(r1, r2 * r1(1) / r2(1), tol) && ArrayIsEqual(l1, l2 * l1(1) / l2(1), tol) && ArrayIsEqual(lambda1, lambda2, tol);

% use one of the results for the remainder of the procedure
l = l2; r = r2; lambda = lambda2;


%% Normalization

% normalize MPS tensor
A = A / sqrt(lambda);
E = ncon({A, conj(A)}, {[-1 1 -3], [-2 1 -4]});

% normalize fixed points
tr = ncon({l, r},{[1 2], [2 1]});
l = l / sqrt(tr); r = r / sqrt(tr);

% checks to see if this is right: ok
checkr = ArrayIsEqual(r, ncon({E, r}, {[-1 -2 1 2], [1 2]}), tol);
checkl = ArrayIsEqual(l, ncon({l, E}, {[1 2], [2 1 -2 -1]}), tol);
checktr = ArrayIsEqual(1, ncon({l, r},{[1 2], [2 1]}), tol);


%% Calculate left and right orthonormal gauge transform

% first option: taking square root of left fixed point; less accurate option
[V, S] = eig(l);
L1 = V * sqrt(S) * V';
[V, S] = eig(r);
R1 = V * sqrt(S) * V';

AL1 = ncon({L1, A, inv(L1)}, {[-1 1], [1 -2 2], [2 -3]}); % MPS tensor in left canonical form
AR1 = ncon({inv(R1), A, R1}, {[-1 1], [1 -2 2], [2 -3]}); % MPS tensor in right canonical form
checkL1 = ArrayIsEqual(eye(D), ncon({AL1, conj(AL1)}, {[1 2 -1], [1 2 -2]}), 1e-9); % check AL: ok, but requires pretty high tolerance
checkR1 = ArrayIsEqual(eye(D), ncon({AR1, conj(AR1)}, {[-1 1 2], [-2 1 2]}), 1e-9); % check AR: ok, but requires pretty high tolerance


% second option: through iterative QR decompositions; more accurate option
L = randcomplex(D, D); % initialize random matrix
L = L / ArrayNorm(L); % normalize
flag = true;
while flag
    [AL2, Lprime] = qrpos(reshape(ncon({L, A}, {[-1 1], [1 -2 -3]}), [D*d, D]));
    lambda = ArrayNorm(Lprime);    Lprime = Lprime / lambda;
    if ArrayIsEqual(L, Lprime, 1e-14)
        flag = false;
    else
        L = Lprime;
    end
end
L2 = Lprime;
AL2 = reshape(AL2, [D d D]);

R = randcomplex(D, D);
R = R / ArrayNorm(R); % normalize
flag = true;
while flag
    [AR2, Rprime] = lq(reshape(ncon({A, R}, {[-1 -2 1], [1 -3]}), [D, d*D]));
    Rprime = Rprime / ArrayNorm(Rprime);
    if ArrayIsEqual(R, Rprime, 1e-14)
        flag = false;
    else
        R = Rprime;
    end
end
R2 = Rprime;
AR2 = reshape(AR2, [D d D]);

checkL2 = ArrayIsEqual(eye(D), ncon({AL2, conj(AL2)}, {[1 2 -1], [1 2 -2]}), tol); % check AL: ok, with lower tolerance
checkL2_extra = ArrayIsEqual(AL2, ncon({L2, A, inv(L2)}, {[-1 1], [1 -2 2], [2, -3]}), tol);
checkR2 = ArrayIsEqual(eye(D), ncon({AR2, conj(AR2)}, {[-1 1 2], [-2 1 2]}), tol); % check AR: ok, with lower tolerance
checkR2_extra = ArrayIsEqual(AR2, ncon({inv(R2), A, R2}, {[-1 1], [1 -2 2], [2, -3]}), tol);

% didn't do the hybrid method using an extra Arnoldi solver step from lecture notes, is this necessary?

% could also directly go to mixed gauge by using AL in the right orthonormalization procedure...

% why would we need the lambda from algorithm 1 box in the lecture notes? Isn't this just always going to be one if the procedure converges?

% use one result for the remainder
L = L2; R = R2; AR = AR2; AL = AL2;

% some extra checks, just for my own sanity; seems fine now
l2 = L'*L;
r2 = R*R';
tr2 = ncon({l2, r2},{[1 2], [2 1]});
l2 = l2 / sqrt(tr2); r2 = r2 / sqrt(tr2);
checkr2 = ArrayIsEqual(r2, ncon({E, r2}, {[-1 -2 1 2], [1 2]}), tol);
checkl2 = ArrayIsEqual(l2, ncon({l2, E}, {[1 2], [2 1 -2 -1]}), tol);
checktr2 = ArrayIsEqual(1, ncon({l2, r2},{[1 2], [2 1]}), tol);


%% Go to mixed gauge

C = L * R;
checkC1 = ArrayIsEqual(ncon({AL, C}, {[-1 -2 1], [1 -3]}), ncon({C, AR}, {[-1 1], [1 -2 -3]}), tol); % check property (16) of the C-matrix

% diagonalize C using SVD
[U, C, V] = svd(C);

%% Apply truncation if desired, default no truncation, t = 0
t = 0;
if t
    % keep t highest values in C and their according unitaries U and V
    U = U(:,1:t);
    C = C(1:t,1:t);
    V = V(:,1:t);
    AL = ncon({U', AL, U}, {[-1 1], [1 -2 2], [2 -3]});
    AR = ncon({V', AR, V}, {[-1 1], [1 -2 2], [2 -3]});
    AC = ncon({AL, C}, {[-1 -2 1], [1 -3]});
    
    checkL = ArrayIsEqual(eye(t), ncon({AL, conj(AL)}, {[1 2 -1], [1 2 -2]}), tol); % doesn't check out after truncating: need to normalize again?
    checkR = ArrayIsEqual(eye(t), ncon({AR, conj(AR)}, {[-1 1 2], [-2 1 2]}), tol); % doesn't check out after truncating: need to normalize again?
    checkC2 = ArrayIsEqual(ncon({AL, C}, {[-1 -2 1], [1 -3]}), ncon({C, AR}, {[-1 1], [1 -2 -3]}), tol); % recheck property (16) of the C-matrix
    
    % entanglement entropy
    S = -sum(C^2*diag(log(C^2)));
    
else
    AL = ncon({U', AL, U}, {[-1 1], [1 -2 2], [2 -3]});
    AR = ncon({V', AR, V}, {[-1 1], [1 -2 2], [2 -3]});
    AC = ncon({AL, C}, {[-1 -2 1], [1 -3]});
    checkL = ArrayIsEqual(eye(D), ncon({AL, conj(AL)}, {[1 2 -1], [1 2 -2]}), tol); % check AL again, just to see if I daggered the right thing just now
    checkR = ArrayIsEqual(eye(D), ncon({AR, conj(AR)}, {[-1 1 2], [-2 1 2]}), tol); % check AR again, just to see if I daggered the right thing just now
    checkC2 = ArrayIsEqual(ncon({AL, C}, {[-1 -2 1], [1 -3]}), ncon({C, AR}, {[-1 1], [1 -2 -3]}), tol); % recheck property (16) of the C-matrix
    
    % entanglement entropy
    S = -sum(C^2*diag(log(C^2)));
end

% renormalize MPS in mixed gauge (is it normal that this is necessary?)
nrm = ncon({AC, conj(AC)}, {[1 2 3], [1 2 3]});
AC = AC/sqrt(nrm);





%% Expectation values of single- and two-site operators

% random one- and two-site operators to test with
O1 = randcomplex(d, d);
O2 = randcomplex(d, d, d, d);

% expectation value of single-site operator
% uniform gauge -> implemented in function ExpvOneBodyUniform
expv1_1 = ncon({l, r, A, conj(A), O1}, {...
    [4 1],...
    [3 6],...
    [1 2 3],...
    [4 5 6],...
    [2 5]});
% mixed gauge -> implemented in function ExpvOneBodyMixed
expv1_2 = ncon({AC, conj(AC), O1}, {...
    [1 2 3],...
    [1 4 3],...
    [2 4]}, [2 1 3 4]);
checkExpv1 = ArrayIsEqual(expv1_1, expv1_2, tol);

% expectation value of two-site operator
% uniform gauge -> implemented in function ExpvTwoBodyUniform
expv2_1 = ncon({l, r, A, A, conj(A), conj(A), O2}, {...
    [6 1],...
    [5 10],...
    [1 2 3],...
    [3 4 5],...
    [6 7 8],...
    [8 9 10],...
    [2 4 7 9]});
% mixed gauge -> implemented in function ExpvTwoBodyMixed
expv2_2 = ncon({AL, AC, conj(AL), conj(AC), O2}, {...
    [1 2 3],...
    [3 4 5],...
    [1 6 7],...
    [7 8 5],...
    [2 4 6 8]}, [3 2 4 1 6 5 8 7]);
checkExpv2 = ArrayIsEqual(expv2_1, expv2_2, tol);


%% Variational optimization of spin-1 Heisenberg Hamiltonian with gradient descent in uniform gauge

% coupling strengths
Jx = 1; Jy = 1; Jz = 1; hz = 0;
% Heisenberg Hamiltonian
h = HeisenbergHamiltonian(Jx, Jy, Jz, hz);

% % most naive approach: converges to same energy as fminunc
% A = randcomplex(D, d, D);
% tl = 1e-4;
% epsilon = 0.1;
% flag = true;
% while flag
%     [e, g] = EnergyDensity(A, h);
%     e
%     Aprime = A - epsilon * g;
%     if ArrayIsEqual(A, Aprime, tl)
%         flag = false;
%     else
%         A = Aprime;
%     end
% end

% running now, converges to the same energy every time
ReA = rand(D, d, D);
ImA = rand(D, d, D);
varA = [reshape(ReA, [], 1); reshape(ImA, [], 1)];
EnergyHandle = @(varA) EnergyWrapper(varA, h, D, d);
options = optimoptions('fminunc', 'SpecifyObjectiveGradient', true);
[Aopt, e] = fminunc(EnergyHandle, varA, options);
Aopt = complex(reshape(Aopt(1:D^2*d), [D d D]), reshape(Aopt(D^2*d+1:end), [D d D]));
[Aopt, l, r] = NormalizeMPS(Aopt);
ArrayIsEqual(e, ExpvTwoSiteUniform(Aopt, l, r, h), tol) % just to be extra sure...

% gradient descent seems to be working now!

%% Variational optimization of spin-1 Heisenberg Hamiltonian with VUMPS

% coupling strengths
Jx = 1; Jy = 1; Jz = 1; hz = 0;
% Heisenberg Hamiltonian
h = HeisenbergHamiltonian(Jx, Jy, Jz, hz);

% running now, converges to the same energy every time
ReA = rand(D, d, D);
ImA = rand(D, d, D);
varA = [reshape(ReA, [], 1); reshape(ImA, [], 1)];
EnergyHandle = @(varA) EnergyWrapper(varA, h, D, d);
options = optimoptions('fminunc', 'SpecifyObjectiveGradient', true);
% [Aopt, e] = fminunc(EnergyHandle, varA, options);
% Aopt = complex(reshape(Aopt(1:D^2*d), [D d D]), reshape(Aopt(D^2*d+1:end), [D d D]));
% [Aopt, l, r] = NormalizeMPS(Aopt);
% ArrayIsEqual(e, ExpvTwoSiteUniform(Aopt, l, r, h), tol)

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% function definitions

%% normalizing/gauging MPS

function E = CreateTransfer(A)
    E = ncon({A, conj(A)}, {[-1 1 -2], [-3 1 -4]});
end

function [A, l, r] = NormalizeMPS(A)
    D = size(A, 1);
    % calculate left and right fixed points
    handleR = @(v) reshape(ncon({A, conj(A), reshape(v, [D D])}, {[-1 2 1], [-2 2 3], [1 3]}), [], 1);
    handleL = @(v) reshape(ncon({A, conj(A), reshape(v, [D D])}, {[1 2 -2], [3 2 -1], [3 1]}), [], 1);
    [r, lambda] = eigs(handleR, D^2, 1); % right eigenvector
    [l, ~] = eigs(handleL, D^2, 1); % left eigenvector
    r = reshape(r, [D D]);
    l = reshape(l, [D D]);
    % normalize MPS tensor
    A = A / sqrt(lambda);
    % normalize fixed points
    tr = ncon({l, r},{[1 2], [2 1]});
    l = l / sqrt(tr); r = r / sqrt(tr);
end

function [AL, L, lambda] = LeftOrthonormalize(A, L0, tol)
    D = size(A, 1); d = size(A, 2);
    if nargin < 3
        tol = 1e-12;
    end
    if nargin < 2
        L = randcomplex(D, D); % initialize random matrix
    else
        L = L0;
    end
    L = L / ArrayNorm(L); % normalize
    flag = true;
    while flag
        [AL, Lprime] = qrpos(reshape(ncon({L, A}, {[-1 1], [1 -2 -3]}), [D*d, D]));
        lambda = ArrayNorm(Lprime);    Lprime = Lprime / lambda;
        if ArrayIsEqual(L, Lprime, tol)
            flag = false;
        else
            L = Lprime;
        end
    end
    L = Lprime;
    AL = reshape(AL, [D d D]);
end

function [AR, R, lambda] = RightOrthonormalize(A, R0, tol)
    D = size(A, 1); d = size(A, 2);
    if nargin < 3
        tol = 1e-12;
    end
    if nargin < 2
        R = randcomplex(D, D); % initialize random matrix
    else
        R = R0;
    end
    flag = true;
    while flag
        [AR, Rprime] = lq(reshape(ncon({A, R}, {[-1 -2 1], [1 -3]}), [D, d*D]));
        lambda = ArrayNorm(Rprime);    Rprime = Rprime / lambda;
        if ArrayIsEqual(R, Rprime, tol)
            flag = false;
        else
            R = Rprime;
        end
    end
    R = Rprime;
    AR = reshape(AR, [D d D]);
end

function [AL, AR, AC, C] = MixedCanonical(A, tol)
    D = size(A, 1);
    R0 = randcomplex(D, D); L0 = randcomplex(D, D); % initialize random matrices
    [AL, L, ~] = LeftOrthonormalize(A, L0, tol);
    [AR, R, ~] = RightOrthonormalize(A, R0, tol);
    [U, C, V] = svd(L * R);
    AL = ncon({U', AL, U}, {[-1 1], [1 -2 2], [2 -3]});
    AR = ncon({V', AR, V}, {[-1 1], [1 -2 2], [2 -3]});
    AC = ncon({AL, C}, {[-1 -2 1], [1 -3]});
    % renormalize MPS in mixed gauge (is it normal that this is necessary?)
    nrm = ncon({AC, conj(AC)}, {[1 2 3], [1 2 3]});
    AC = AC / sqrt(nrm);
end

%% expectation values of on- and two-site operators in uniform and mixed gauge

function expv = ExpvOneSiteUniform(A, l, r, O)
    expv = ncon({l, r, A, conj(A), O}, {...
        [4 1],...
        [3 6],...
        [1 2 3],...
        [4 5 6],...
        [2 5]});
end

function expv = ExpvOneSiteMixed(AC, O)
    expv = ncon({AC, conj(AC), O}, {...
        [1 2 3],...
        [1 4 3],...
        [2 4]}, [2 1 3 4]);
end

function expv = ExpvTwoSiteUniform(A, l, r, O)
    expv = ncon({l, r, A, A, conj(A), conj(A), O}, {...
        [6 1],...
        [5 10],...
        [1 2 3],...
        [3 4 5],...
        [6 7 8],...
        [8 9 10],...
        [2 4 7 9]});
end

function expv = ExpvTwoSiteMixed(AC, AL, O)
    expv = ncon({AL, AC, conj(AL), conj(AC), O}, {...
        [1 2 3],...
        [3 4 5],...
        [1 6 7],...
        [7 8 5],...
        [2 4 6 8]}, [3 2 4 1 6 5 8 7]);
end

%% spin-1 Heisenberg Hamiltonian

function h = HeisenbergHamiltonian(Jx, Jy, Jz, hz)
    % spin-1 angular momentum operators
    Sx = [0 1 0; 1 0 1; 0 1 0] / sqrt(2);
    Sy = [0 -1 0; 1 0 -1; 0 1 0] * 1i / sqrt(2);
    Sz = [1 0 0; 0 0 0; 0 0 -1];
    % Heisenberg Hamiltonian
    h = -Jx*ncon({Sx, Sx}, {[-1 -3], [-2 -4]}) - Jy*ncon({Sy, Sy}, {[-1 -3], [-2 -4]}) - Jz*ncon({Sz, Sz}, {[-1 -3], [-2 -4]})...
            - hz*ncon({Sz, eye(3)}, {[-1 -3], [-2 -4]}) - hz*ncon({eye(3), eye(3)}, {[-1 -3], [-2 -4]});
end

%% MPS optimization in uniform gauge using gradient descent

function g = EnergyGradient(A, l, r, htilde)
    D = size(A, 1);
    % center terms first; easy ones
    centerTerm1 = ncon({l, r, A, A, conj(A), htilde}, {...
        [6 1],...
        [5 -3],...
        [1 3 2],...
        [2 4 5],...
        [6 7 -1],...
        [3 4 7 -2]});
    centerTerm2 = ncon({l, r, A, A, conj(A), htilde}, {...
        [-1 1],...
        [5 7],...
        [1 3 2],...
        [2 4 5],...
        [-3 6 7],...
        [3 4 -2 6]});
    
    % left environment
    xL =  ncon({l, A, A, conj(A), conj(A), htilde}, {...
        [5 1],...
        [1 3 2],...
        [2 4 -2],...
        [5 6 7],...
        [7 8 -1],...
        [3 4 6 8]});
    handleL = @(v) reshape(reshape(v, [D D]) - ncon({reshape(v, [D D]), A, conj(A)}, {[3 1], [1 2 -2], [3 2 -1]}) + trace(reshape(v, [D D])*r) * l, [], 1);
    Lh = reshape(gmres(handleL, reshape(xL, [], 1)), [D D]);
    leftEnv = ncon({Lh, A, r}, {[-1 1], [1 -2 2], [2 -3]});
    
    % right environment
    xR =  ncon({r, A, A, conj(A), conj(A), htilde}, {...
        [4 5],...
        [-1 2 1],...
        [1 3 4],...
        [-2 8 7],...
        [7 6 5],...
        [2 3 8 6]});
    handleR = @(v) reshape(reshape(v, [D D]) - ncon({reshape(v, [D D]), A, conj(A)}, {[1 3], [-1 2 1], [-2 2 3]}) + trace(l*reshape(v, [D D])) * r, [], 1);
    Rh = reshape(gmres(handleR, reshape(xR, [], 1)), [D D]);
    rightEnv = ncon({Rh, A, l}, {[1 -3], [2 -2 1], [-1 2]});
    
    % construct gradient out of these 4 terms
    g = 2 * (centerTerm1 + centerTerm2 + leftEnv + rightEnv);
end

function [e, g] = EnergyDensity(A, h)
    d = size(A, 2);
    [A, l, r] = NormalizeMPS(A); % normalize MPS
    e = real(ExpvTwoSiteUniform(A, l, r, h)); % compute energy density of MPS (discard numerical imaginary artefact)
    htilde = h - e * ncon({eye(d), eye(d)}, {[-1 -3], [-2 -4]}); % regularized energy density
    g = EnergyGradient(A, l, r, htilde); % calculate gradient of energy density
end

function [e, g] = EnergyWrapper(varA, h, D, d)
    A = complex(reshape(varA(1:D^2*d), [D d D]), reshape(varA(D^2*d+1:end), [D d D]));
    [e, g] = EnergyDensity(A, h);
    g = [reshape(real(g), [], 1); reshape(imag(g), [], 1)];
end

%% VUMPS algorithm for spin-1 chain

function Rh = RightEnvMixed(AR, htilde)
    D = size(AL, 1);
    xR =  ncon({AR, AR, conj(AR), conj(AR), htilde}, {...
        [-1 2 1],...
        [1 3 4],...
        [-2 7 6],...
        [6 5 4],...
        [2 3 7 5]});
    % don't actually know left fixed point of AR with eigenvalue one, or do we? because we need it to regularize the left transfer matrix
    handleL = @(v) reshape(ncon({AR, conj(AR), reshape(v, [D D])}, {[1 2 -2], [3 2 -1], [3 1]}), [], 1); % handle for determining right fixed point of AR
    [l, ~] = eigs(handleL, D^2, 1); l = reshape(l, [D D]);  l = l / sqrt(trace(l)); % right eigenvector of AL
    
    handleR = @(v) reshape(reshape(v, [D D]) - ncon({reshape(v, [D D]), AR, conj(AR)}, {[1 3], [-1 2 1], [-2 2 3]}) + trace(l*reshape(v, [D D])) * eye(D), [], 1);
    Rh = reshape(gmres(handleR, reshape(xR, [], 1)), [D D]);
end

function Lh = LeftEnvMixed(AL, htilde)
    D = size(AL, 1);
    xL =  ncon({AL, AL, conj(AL), conj(AL), htilde}, {...
        [4 2 1],...
        [1 3 -2],...
        [4 5 6],...
        [6 7 -1],...
        [2 3 5 7]});
    % don't actually know right fixed point of AL with eigenvalue one, or do we? because we need it to regularize the left transfer matrix
    handleR = @(v) reshape(ncon({AL, conj(AL), reshape(v, [D D])}, {[-1 2 1], [-2 2 3], [1 3]}), [], 1); % handle for determining right fixed point of AL
    [r, ~] = eigs(handleR, D^2, 1); r = reshape(r, [D D]);  r = r / sqrt(trace(r)); % right eigenvector of AL
    
    handleL = @(v) reshape(reshape(v, [D D]) - ncon({reshape(v, [D D]), AL, conj(AL)}, {[3 1], [1 2 -2], [3 2 -1]}) + trace(reshape(v, [D D])*r) * eye(D), [], 1);
    Lh = reshape(gmres(handleL, reshape(xL, [], 1)), [D D]);
end

function vprime = H_AC(v, AL, AR, Rh, Lh, htilde)
    
end

function vprime = H_C(v, AL, AR, Rh, Lh, htilde)
    
end

function [ACprime, Cprime] = CalculateNewCenter(AL, AR, AC, C, htilde)
    Rh = RightEnvMixed(AR, htilde);
    Lh = LeftEnvMixed(AL, htilde);
    
    % compute action of maps (131) and (132) on a vector of the size of AC, and pour this into function handle...
    
    % use eigs with smallestreal option...
end

