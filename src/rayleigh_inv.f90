!=======================================================================
!   SEIS_FILO: 
!   SEISmological tools for Flat Isotropic Layered structure in the Ocean
!   Copyright (C) 2019 Takeshi Akuhara
!
!   This program is free software: you can redistribute it and/or modify
!   it under the terms of the GNU General Public License as published by
!   the Free Software Foundation, either version 3 of the License, or
!   (at your option) any later version.
!
!   This program is distributed in the hope that it will be useful,
!   but WITHOUT ANY WARRANTY; without even the implied warranty of
!   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
!   GNU General Public License for more details.
!
!   You should have received a copy of the GNU General Public License
!   along with this program.  If not, see <https://www.gnu.org/licenses/>.
!
!
!   Contact information
!
!   Email  : akuhara @ eri. u-tokyo. ac. jp 
!   Address: Earthquake Research Institute, The Univesity of Tokyo
!           1-1-1, Yayoi, Bunkyo-ku, Tokyo 113-0032, Japan
!
!=======================================================================
program main
  use mod_random
  use mod_trans_d_model
  use mod_mcmc
  use mod_rayleigh
  use mod_interpreter
  use mod_const
  use mod_observation
  implicit none 
  include 'mpif.h'

  integer, parameter :: n_iter = 100000
  integer, parameter :: k_min = 1, k_max = 21
  integer, parameter :: n_rx = 3
  double precision, parameter :: vs_min = 2.5d0, vs_max = 5.0d0
  double precision, parameter :: vp_min = 5.0d0, vp_max = 8.5d0
  double precision, parameter :: z_min = 0.d0, z_max = 30.d0
  double precision, parameter :: dev_vs = 0.03d0
  double precision, parameter :: dev_vp = 0.03d0
  double precision, parameter :: dev_z  = 0.03d0
  integer, parameter :: nbin_z = 50, nbin_vs = 50

  logical, parameter :: solve_vp = .true.
  logical, parameter :: ocean_flag = .false.
  double precision :: ocean_thick = 1.d0

  double precision, parameter :: cmin = 0.2d0 * vs_min, &
       &  cmax = 4.5d0, dc = 0.005d0
  double precision :: fmin, fmax, df
  
  integer :: i, ierr, nproc, rank
  double precision :: log_likelihood
  logical :: is_ok
  type(vmodel) :: vm
  type(trans_d_model) :: tm, tm_tmp
  type(interpreter) :: intpr
  type(mcmc) :: mc
  type(rayleigh) :: ray
  type(observation) :: obs

  ! MPI 

  call mpi_init(ierr)
  call mpi_comm_size(MPI_COMM_WORLD, nproc, ierr)
  call mpi_comm_rank(MPI_COMM_WORLD, rank, ierr)

  call init_random(22222322, 2246789, 123147890, 65678901, rank)
  
  ! Read observation file
  obs = init_observation("rayobs.in")
  fmin = obs%get_fmin()
  df   = obs%get_df()
  fmax = fmin + df * (obs%get_nf() - 1)


  ! Set model parameter & generate initial sample
  tm = init_trans_d_model(k_min=k_min, k_max=k_max, n_rx=n_rx)
  call tm%set_prior(id_vs, id_uni, vs_min, vs_max)
  call tm%set_prior(id_vp, id_uni, vp_min, vp_max)
  call tm%set_prior(id_z,  id_uni, z_min,  z_max )
  call tm%set_birth(id_vs, id_uni, vs_min, vs_max)
  call tm%set_birth(id_vp, id_uni, vp_min, vp_max)
  call tm%set_birth(id_z,  id_uni, z_min,  z_max )
  call tm%set_perturb(id_vs, dev_vs)
  call tm%set_perturb(id_vp, dev_vp)
  call tm%set_perturb(id_z,  dev_z)
  call tm%generate_model()

  ! Set interpreter 
  intpr = init_interpreter(nlay_max=k_max, &
       & z_min=z_min, z_max=z_max, nbin_z=nbin_z, &
       & vs_min=vs_min, vs_max=vs_max, nbin_vs=nbin_vs, &
       & ocean_flag =ocean_flag, ocean_thick=ocean_thick, &
       & solve_vp=solve_vp)
  vm = intpr%get_vmodel(tm)
  call vm%display()
  
  ! Set forward computation
  ray = init_rayleigh(vm=vm, fmin=obs%fmin, fmax=fmax, df=df, &
       cmin=cmin, cmax=cmax, dc=dc)
  
  ! Set MCMC chain
  mc = init_mcmc(tm, n_iter, n_corr=2000)

  ! Main
  do i = 1, n_iter
     call mc%propose_model(tm_tmp, is_ok)
     if (is_ok) then
        call forward_rayleigh(tm_tmp, intpr, obs, ray, log_likelihood)
     else
        log_likelihood = -1.d300
     end if
     call mc%judge_model(tm_tmp, log_likelihood)
     call mc%one_step_summary()


  end do

  ! Output
  do i = 1, mc%get_n_mod()
     write(*,*)i
     tm = mc%get_tm_saved(i)
     vm = intpr%get_vmodel(tm)
     call vm%display()
  end do

  call ray%set_vmodel(vm)
  call ray%dispersion()
  
  do i = 1, obs%get_nf()
     write(111,*)obs%get_fmin() + (i-1) * obs%get_df(), &
          & ray%get_c(i), obs%get_c(i), ray%get_u(i), obs%get_u(i)
  end do

  stop
end program main


!-----------------------------------------------------------------------

subroutine forward_rayleigh(tm, intpr, obs, ray, log_likelihood)
  use mod_trans_d_model
  use mod_interpreter
  use mod_observation
  use mod_rayleigh
  use mod_vmodel
  implicit none 
  type(trans_d_model), intent(in) :: tm
  type(interpreter), intent(inout) :: intpr
  type(observation), intent(in) :: obs
  type(rayleigh), intent(inout) :: ray
  double precision, intent(out) :: log_likelihood
  type(vmodel) :: vm
  integer :: i
  
  ! calculate synthetic dispersion curves
  vm = intpr%get_vmodel(tm)
  call ray%set_vmodel(vm)
  call ray%dispersion()
  
  ! calc misfit
  log_likelihood = 0.d0
  do i = 1, obs%get_nf()
     log_likelihood = &
          & log_likelihood - (ray%get_c(i) - obs%get_c(i)) ** 2 / &
          & (obs%get_sig_c(i) ** 2)
     log_likelihood = &
          & log_likelihood - (ray%get_u(i) - obs%get_u(i)) ** 2 / &
          & (obs%get_sig_u(i) ** 2)

  end do
  !do i = 1, obs%get_nf()
  !   write(*,*)i, ray%get_c(i), obs%get_c(i)
  !end do
  log_likelihood = 0.5d0 * log_likelihood

  return 
end subroutine forward_rayleigh
